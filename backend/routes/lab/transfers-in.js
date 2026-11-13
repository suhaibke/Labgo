// Lab-to-lab on LabGo, receiving side (+ the directory, quotes and
// notifications both sides use). A sample sent to a registered lab shows up
// here; the receiving lab receives it by its barcode, enters the results (or
// uploads a file/photo) and the result goes straight back to the sending lab.
const express = require('express');
const mongoose = require('mongoose');
const ExternalTransfer = require('../../models/ExternalTransfer');
const Order = require('../../models/Order');
const Lab = require('../../models/Lab');
const Notification = require('../../models/Notification');
const r2Service = require('../../services/r2Service');
const reportPdf = require('../../services/reportPdfService');
const labTransfers = require('../../services/labTransferService');
const { notifyLab } = require('../../services/labNotify');
const { r2SingleUpload } = require('../../middleware/r2Upload');
const { classify } = require('../../helpers/result-ranges');
const { buildRows } = require('./results');

const router = express.Router();
const uploadIncomingResult = r2SingleUpload('results', 'resultFile', 'b2b-result-');

function langOf(req) {
    const currentLang = req.cookies?.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
    return {
        currentLang,
        direction: ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr',
        font: currentLang === 'ar' ? 'Cairo, sans-serif' : 'Inter, sans-serif',
    };
}

// ---------- directory and price quote (sending side) ----------
router.get('/api/labs/directory', async (req, res) => {
    try {
        res.json({ success: true, data: { labs: await labTransfers.directory(req.lab._id, req.query.q) } });
    } catch (error) {
        console.error('Lab directory error:', error);
        res.status(500).json({ success: false, message: 'Error loading labs' });
    }
});

// Price the receiving lab charges for these tests (its B2B prices).
router.get('/api/labs/:id/quote', async (req, res) => {
    try {
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) return res.status(404).json({ success: false, message: 'Lab not found' });
        const lab = await Lab.findOne({ _id: req.params.id, status: 'Active' }).select('name tests');
        if (!lab) return res.status(404).json({ success: false, message: 'Lab not found' });
        const names = String(req.query.tests || '').split(/[,،\n]/).map((s) => s.trim()).filter(Boolean).slice(0, 50);
        res.json({ success: true, data: labTransfers.quote(lab, names) });
    } catch (error) {
        console.error('Lab quote error:', error);
        res.status(500).json({ success: false, message: 'Error getting the price' });
    }
});

// ---------- notifications (this user's) ----------
router.get('/api/notifications', async (req, res) => {
    try {
        const [items, unread] = await Promise.all([
            Notification.find({ userId: req.user._id }).sort({ createdAt: -1 }).limit(40).lean(),
            Notification.countDocuments({ userId: req.user._id, isRead: false }),
        ]);
        res.json({ success: true, data: { unread, items: items.map((n) => ({ id: String(n._id), title: n.title, body: n.body, data: n.data || {}, isRead: n.isRead, createdAt: n.createdAt })) } });
    } catch (error) {
        console.error('Notifications error:', error);
        res.status(500).json({ success: false, message: 'Error loading notifications' });
    }
});

router.post('/api/notifications/read', async (req, res) => {
    try {
        const ids = Array.isArray(req.body?.ids) ? req.body.ids.filter((id) => mongoose.Types.ObjectId.isValid(id)) : null;
        const query = { userId: req.user._id, isRead: false };
        if (ids) query._id = { $in: ids };
        await Notification.updateMany(query, { $set: { isRead: true } });
        res.json({ success: true });
    } catch (error) {
        console.error('Notifications read error:', error);
        res.status(500).json({ success: false, message: 'Error updating notifications' });
    }
});

// ---------- incoming samples (receiving side) ----------
function testNames(t) {
    const names = (t.tests || []).map((x) => x.testName).filter(Boolean);
    return names.length ? names : String(t.testsDescription || '').split(/[,،\n]/).map((s) => s.trim()).filter(Boolean);
}

// The transfer in the shape the results page and the report expect.
function asOrder(t) {
    return {
        _id: t._id,
        qrCode: t.sampleCode,
        createdAt: t.receivedAt || t.sentAt,
        tests: testNames(t).map((testName) => ({ testName })),
        results: t.receiverResults || {},
        walkIn: {},
        patientInfo: {
            name: t.patientName, gender: t.patientGender || null, age: Number.isInteger(t.patientAge) ? t.patientAge : null,
            phone: null, patientNo: null, birthDate: null,
        },
    };
}

function summary(t, fromLabName) {
    return {
        id: String(t._id),
        code: t.sampleCode,
        patient: t.patientName,
        gender: t.patientGender || null,
        age: Number.isInteger(t.patientAge) ? t.patientAge : null,
        tests: testNames(t),
        fromLab: fromLabName || '',
        price: t.price,
        sentAt: t.sentAt,
        receivedAt: t.receivedAt || null,
        status: t.status === 'completed' ? 'completed' : (t.receivedAt ? 'received' : 'on_the_way'),
        entryStatus: t.receiverResults?.entryStatus || 'none',
        fileUrl: t.status === 'completed' ? (t.resultFileUrl || null) : null,
        values: Object.fromEntries((t.receiverResults?.values || []).filter((v) => v.value).map((v) => [v.testName, v.value])),
    };
}

router.get('/api/transfers/incoming', async (req, res) => {
    try {
        const list = await ExternalTransfer.find({ toLabId: req.lab._id }).sort({ sentAt: -1 }).limit(150).populate('labId', 'name').lean();
        res.json({ success: true, data: { items: list.map((t) => summary(t, t.labId?.name)) } });
    } catch (error) {
        console.error('Incoming transfers error:', error);
        res.status(500).json({ success: false, message: 'Error loading incoming samples' });
    }
});

// Receive by the barcode on the label (sample code).
router.post('/api/transfers/incoming/receive', async (req, res) => {
    try {
        const code = String(req.body?.code || '').trim();
        if (!code) return res.status(400).json({ success: false, message: 'Scan or type the sample code', code: 'code' });
        const t = await ExternalTransfer.findOne({ toLabId: req.lab._id, sampleCode: new RegExp(`^${code.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') });
        if (!t) return res.status(404).json({ success: false, message: 'No sample with this code was sent to your lab', code: 'notFound' });
        if (!t.receivedAt) {
            t.receivedAt = new Date();
            t.receivedBy = req.user._id;
            await t.save();
            await notifyLab(t.labId, {
                title: 'تم استلام العينة',
                body: `${req.lab.name} استلم العينة ${t.sampleCode} (${t.patientName})`,
                data: { type: 'transfer_received', transferId: String(t._id), sampleCode: t.sampleCode },
            });
        }
        const from = await Lab.findById(t.labId).select('name');
        res.json({ success: true, data: summary(t, from?.name) });
    } catch (error) {
        console.error('Receive sample error:', error);
        res.status(500).json({ success: false, message: 'Error receiving the sample' });
    }
});

async function incoming(req, res) {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
        res.status(404).json({ success: false, message: 'Sample not found' });
        return null;
    }
    const t = await ExternalTransfer.findOne({ _id: req.params.id, toLabId: req.lab._id });
    if (!t) {
        res.status(404).json({ success: false, message: 'Sample not found' });
        return null;
    }
    return t;
}

function payload(t) {
    const o = asOrder(t);
    return {
        order: { _id: o._id, qrCode: o.qrCode, status: t.status, createdAt: o.createdAt, patientInfo: o.patientInfo,
            results: { comment: t.receiverResults?.comment || '', entryStatus: t.receiverResults?.entryStatus || 'none', reportUrl: t.resultFileUrl || null } },
        rows: [],
    };
}

function setValues(t, rows, body, userId) {
    const incomingValues = Array.isArray(body.values) ? body.values : [];
    const byName = new Map(incomingValues.map((v) => [String(v.testName), v]));
    const values = rows.map((r) => {
        const v = byName.get(r.testName);
        const value = v ? String(v.value ?? '').trim().slice(0, 200) : r.value;
        return { testName: r.testName, value, unit: r.unit, min: r.min, max: r.max, normalText: r.normalText, flag: classify(value, r.min, r.max) };
    });
    if (!t.receiverResults) t.receiverResults = {};
    t.receiverResults.values = values;
    if (typeof body.comment === 'string') t.receiverResults.comment = body.comment.trim().slice(0, 2000);
    t.receiverResults.enteredAt = new Date();
    return values;
}

function rowsFor(t, lab) {
    return buildRows(asOrder(t), lab);
}

// Results page for an incoming sample (same page as orders).
router.get('/transfers/incoming/:id/results', async (req, res) => {
    try {
        const t = mongoose.Types.ObjectId.isValid(req.params.id) ? await ExternalTransfer.findOne({ _id: req.params.id, toLabId: req.lab._id }) : null;
        if (!t) return res.redirect('/lab/external-transfers?tab=incoming');
        const data = payload(t);
        data.rows = rowsFor(t, req.lab);
        res.render('dashboard/lab-results-entry', {
            lab: req.lab, user: req.user, title: req.lab.name, ...langOf(req), activeSection: 'external-transfers',
            order: data.order, rows: data.rows, editable: t.status !== 'completed' || t.resultSource === 'receiving_lab',
            initialJson: JSON.stringify(data).replace(/</g, '\\u003c'),
            apiBase: `/lab/api/transfers/incoming/${t._id}`, backHref: '/lab/external-transfers?tab=incoming',
        });
    } catch (error) {
        console.error('Incoming results page error:', error);
        res.status(500).render('error', { message: 'Error loading results', error: null });
    }
});

router.get('/api/transfers/incoming/:id/results', async (req, res) => {
    try {
        const t = await incoming(req, res);
        if (!t) return;
        const data = payload(t);
        data.rows = rowsFor(t, req.lab);
        res.json({ success: true, data });
    } catch (error) {
        console.error('Incoming results error:', error);
        res.status(500).json({ success: false, message: 'Error loading results' });
    }
});

router.put('/api/transfers/incoming/:id/results', async (req, res) => {
    try {
        const t = await incoming(req, res);
        if (!t) return;
        setValues(t, rowsFor(t, req.lab), req.body || {}, req.user._id);
        if (t.receiverResults.entryStatus !== 'approved') t.receiverResults.entryStatus = 'draft';
        if (!t.receivedAt) { t.receivedAt = new Date(); t.receivedBy = req.user._id; }
        await t.save();
        const data = payload(t);
        data.rows = rowsFor(t, req.lab);
        res.json({ success: true, data });
    } catch (error) {
        console.error('Incoming results save error:', error);
        res.status(500).json({ success: false, message: 'Error saving results' });
    }
});

// The sending lab's order gets the values as a draft to review and approve.
async function copyToSenderOrder(t) {
    if (!t.orderId) return;
    const order = await Order.findById(t.orderId);
    if (!order || order.results?.entryStatus === 'approved') return;
    const byName = new Map((t.receiverResults?.values || []).map((v) => [v.testName, v.value]));
    const prev = new Map((order.results?.values || []).map((v) => [v.testName, v]));
    if (!order.results) order.results = {};
    order.results.values = (order.tests || []).map((x) => {
        const old = prev.get(x.testName) || {};
        const value = byName.has(x.testName) ? byName.get(x.testName) : (old.value || '');
        return { testId: x.testId, testName: x.testName, value, unit: old.unit || '', min: old.min ?? null, max: old.max ?? null, normalText: old.normalText || '', flag: old.flag || '' };
    });
    order.results.entryStatus = 'draft';
    order.results.enteredAt = new Date();
    await order.save();
}

async function finish(t, req, fileUrl) {
    t.status = 'completed';
    t.completedAt = new Date();
    t.resultFileUrl = fileUrl;
    t.resultSource = 'receiving_lab';
    if (!t.receivedAt) { t.receivedAt = new Date(); t.receivedBy = req.user._id; }
    await t.save();
    await copyToSenderOrder(t);
    await notifyLab(t.labId, {
        title: 'وصلت نتيجة العينة',
        body: `${req.lab.name} أرسل نتيجة العينة ${t.sampleCode} (${t.patientName})`,
        data: { type: 'transfer_result', transferId: String(t._id), sampleCode: t.sampleCode, orderId: t.orderId ? String(t.orderId) : null },
    });
}

router.post('/api/transfers/incoming/:id/results/approve', async (req, res) => {
    try {
        const t = await incoming(req, res);
        if (!t) return;
        const values = setValues(t, rowsFor(t, req.lab), req.body || {}, req.user._id);
        const missing = values.filter((v) => !v.value).map((v) => v.testName);
        if (missing.length) return res.status(400).json({ success: false, message: 'Some tests have no value', missing });
        t.receiverResults.entryStatus = 'approved';
        t.receiverResults.approvedAt = new Date();
        t.receiverResults.approvedBy = req.user._id;
        let fileUrl = typeof req.body?.reportUrl === 'string' && req.body.reportUrl ? req.body.reportUrl : null;
        if (!fileUrl) {
            try {
                const pdf = await reportPdf.buildReportPdf({ order: asOrder(t), lab: req.lab, rows: rowsFor(t, req.lab), approvedBy: req.user.name, baseUrl: null });
                const name = r2Service.generateUniqueFilename(`${t.sampleCode}.pdf`, 'b2b-report-');
                fileUrl = (await r2Service.uploadBuffer(pdf, r2Service.r2Config.paths.results, name, { contentType: 'application/pdf' })).url;
            } catch (error) {
                if (error.code === 'pdfUnavailable') return res.status(503).json({ success: false, code: 'pdfUnavailable', message: 'The server cannot build PDF reports right now' });
                throw error;
            }
        }
        await finish(t, req, fileUrl);
        const data = payload(t);
        data.rows = rowsFor(t, req.lab);
        res.json({ success: true, data });
    } catch (error) {
        console.error('Incoming results approve error:', error);
        res.status(500).json({ success: false, message: 'Error sending the result' });
    }
});

router.get('/api/transfers/incoming/:id/report.pdf', async (req, res) => {
    try {
        const t = await incoming(req, res);
        if (!t) return;
        const pdf = await reportPdf.buildReportPdf({ order: asOrder(t), lab: req.lab, rows: rowsFor(t, req.lab), approvedBy: req.user.name, baseUrl: null });
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `inline; filename="${String(t.sampleCode).replace(/[^\w.-]/g, '')}.pdf"`);
        res.send(pdf);
    } catch (error) {
        if (error.code === 'pdfUnavailable') return res.status(503).json({ success: false, code: 'pdfUnavailable' });
        console.error('Incoming report error:', error);
        res.status(500).json({ success: false, message: 'Error building the report' });
    }
});

// The result as a file or photo instead of typed values. Returns the file URL
// (the results page then approves with it), or finishes when finish=1.
router.post('/api/transfers/incoming/:id/upload-result', ...uploadIncomingResult, async (req, res) => {
    try {
        const t = await incoming(req, res);
        if (!t) return;
        if (!req.file?.r2Url) return res.status(400).json({ success: false, message: 'No result file provided' });
        if (String(req.query.finish || req.body?.finish) === '1') await finish(t, req, req.file.r2Url);
        res.json({ success: true, data: { fileUrl: req.file.r2Url } });
    } catch (error) {
        console.error('Incoming result upload error:', error);
        res.status(500).json({ success: false, message: 'Error uploading the result' });
    }
});

module.exports = router;
module.exports.asOrder = asOrder;
module.exports.summary = summary;
