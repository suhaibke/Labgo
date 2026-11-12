const express = require('express');
const Order = require('../../models/Order');
const ExternalTransfer = require('../../models/ExternalTransfer');
const { __: translateHelper } = require('../../helpers/i18n-helper');
const { decorateOrderWithPatientInfo, calculateAge } = require('../../helpers/order-patient-info');
const {
    ExternalTransferError,
    buildCommonFields,
    resolveOrderTests,
} = require('../../services/externalTransferService');
const { r2SingleUpload } = require('../../middleware/r2Upload');
const r2Service = require('../../services/r2Service');

const router = express.Router();
const patientFields = 'name phone gender birthDate';

const uploadTransferResult = r2SingleUpload('results', 'resultFile', 'ext-result-');

function serializeForHtml(value) {
    return JSON.stringify(value).replace(/</g, '\\u003c');
}

router.get('/external-transfers', async (req, res) => {
    try {
        const currentLang = req.cookies?.lang
            || req.headers['accept-language']?.split(',')[0]?.split('-')[0]
            || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = currentLang === 'ar' ? 'Cairo, sans-serif' : 'Inter, sans-serif';

        const [transfers, rawEligibleOrders, linkedOrderIds] = await Promise.all([
            ExternalTransfer.find({ labId: req.lab._id }).sort({ sentAt: -1 }).lean(),
            Order.find({
                labId: req.lab._id,
                status: { $nin: ['cancelled', 'completed'] },
            })
                .populate('patientId', patientFields)
                .sort({ createdAt: -1 })
                .lean(),
            ExternalTransfer.distinct('orderId', { labId: req.lab._id, orderId: { $ne: null } }),
        ]);

        const linkedIdSet = new Set(linkedOrderIds.map((id) => String(id)));
        const eligibleOrdersRaw = rawEligibleOrders.filter((order) => !linkedIdSet.has(String(order._id)));
        const eligibleOrders = eligibleOrdersRaw.map((order) => decorateOrderWithPatientInfo(order));

        const requestedOrderId = typeof req.query.orderId === 'string' ? req.query.orderId : '';
        const selectedOrderId = eligibleOrders.some((order) => String(order._id) === requestedOrderId)
            ? requestedOrderId
            : '';

        res.render('dashboard/lab-external-transfers', {
            lab: req.lab,
            user: req.user,
            title: `${translateHelper('externalTransfers.title', currentLang)} - ${req.lab.name}`,
            currentLang,
            direction,
            font,
            activeSection: 'external-transfers',
            transfers,
            eligibleOrders,
            selectedOrderId,
            stats: {
                total: transfers.length,
                awaiting: transfers.filter((t) => t.status === 'sent').length,
                completed: transfers.filter((t) => t.status === 'completed').length,
            },
            transferDataJson: serializeForHtml(transfers),
            eligibleOrdersJson: serializeForHtml(eligibleOrders),
        });
    } catch (error) {
        console.error('External transfers page error:', error);
        res.status(500).render('error', {
            message: 'Error loading external sample transfers',
            error: process.env.NODE_ENV === 'development' ? error.message : null,
        });
    }
});

// Create a transfer - either linked to a real system order (orderId given)
// or entered entirely by hand (patientName + friends given instead).
router.post('/api/external-transfers', async (req, res) => {
    try {
        const { orderId } = req.body;
        const fields = buildCommonFields(req.body, { userId: req.user._id });

        if (orderId) {
            const order = await Order.findById(orderId).populate('patientId', patientFields);
            if (!order) {
                return res.status(404).json({ success: false, message: 'Order not found' });
            }
            if (order.labId.toString() !== req.lab._id.toString()) {
                return res.status(403).json({ success: false, message: 'This order does not belong to your lab' });
            }
            if (order.status === 'cancelled' || order.status === 'completed') {
                return res.status(409).json({ success: false, message: 'This order can no longer be transferred' });
            }

            const alreadyLinked = await ExternalTransfer.findOne({ orderId: order._id });
            if (alreadyLinked) {
                return res.status(409).json({ success: false, message: 'This sample already has an external lab transfer' });
            }

            fields.labId = req.lab._id;
            fields.orderId = order._id;
            fields.sampleCode = order.qrCode;
            fields.patientName = order.patientId?.name || 'Unknown';
            fields.patientPhone = order.patientId?.phone || undefined;
            fields.patientGender = order.patientId?.gender || null;
            fields.patientAge = calculateAge(order.patientId?.birthDate);
            fields.tests = resolveOrderTests(order, req.body.testIds);
        } else {
            const patientName = (req.body.patientName || '').trim();
            if (!patientName) {
                return res.status(400).json({ success: false, message: 'Patient name is required' });
            }

            fields.labId = req.lab._id;
            fields.sampleCode = (req.body.sampleCode || '').trim() || ExternalTransfer.generateSampleCode();
            fields.patientName = patientName;
            fields.patientPhone = (req.body.patientPhone || '').trim() || undefined;
            fields.patientGender = ['male', 'female'].includes(req.body.patientGender) ? req.body.patientGender : null;
            const age = Number(req.body.patientAge);
            fields.patientAge = Number.isFinite(age) && age >= 0 ? age : null;
            const testsDescription = (req.body.testsDescription || '').trim();
            if (testsDescription) fields.testsDescription = testsDescription;
        }

        const transfer = await ExternalTransfer.create(fields);

        return res.status(201).json({
            success: true,
            message: 'External sample transfer saved',
            data: { transfer },
        });
    } catch (error) {
        if (error instanceof ExternalTransferError) {
            return res.status(error.statusCode).json({ success: false, message: error.message });
        }
        if (error.name === 'CastError' || error.name === 'ValidationError') {
            return res.status(400).json({ success: false, message: error.message });
        }

        console.error('Create external transfer error:', error);
        return res.status(500).json({ success: false, message: 'Error saving external sample transfer' });
    }
});

// Upload the result that came back from the external lab, and mark the
// transfer completed. When the transfer is linked to a real order, this
// also completes that order (same effect as the normal in-house result
// upload) so the patient sees their result and gets notified as usual.
router.post('/api/external-transfers/:id/result', ...uploadTransferResult, async (req, res) => {
    try {
        const transfer = await ExternalTransfer.findById(req.params.id);
        if (!transfer || transfer.labId.toString() !== req.lab._id.toString()) {
            return res.status(404).json({ success: false, message: 'Transfer not found' });
        }
        if (!req.file || !req.file.r2Url) {
            return res.status(400).json({ success: false, message: 'No result file provided' });
        }

        const completedAt = new Date();
        transfer.status = 'completed';
        transfer.completedAt = completedAt;
        transfer.resultFileUrl = req.file.r2Url;
        await transfer.save();

        if (transfer.orderId) {
            const order = await Order.findById(transfer.orderId);
            if (order && order.status !== 'completed') {
                await order.markCompleted(req.user._id, req.file.r2Url);
            }
        }

        return res.json({ success: true, data: { transfer } });
    } catch (error) {
        console.error('Upload external transfer result error:', error);
        return res.status(500).json({ success: false, message: 'Error uploading result' });
    }
});

router.delete('/api/external-transfers/:id', async (req, res) => {
    try {
        const transfer = await ExternalTransfer.findById(req.params.id);
        if (!transfer || transfer.labId.toString() !== req.lab._id.toString()) {
            return res.status(404).json({ success: false, message: 'Transfer not found' });
        }
        if (transfer.resultFileUrl) {
            await r2Service.deleteFile(transfer.resultFileUrl).catch(() => {});
        }
        await transfer.deleteOne();
        return res.json({ success: true });
    } catch (error) {
        console.error('Delete external transfer error:', error);
        return res.status(500).json({ success: false, message: 'Error deleting transfer' });
    }
});

module.exports = router;
