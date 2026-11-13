// Lab reception: register a patient who is at the lab and create their order.
const express = require('express');
const Package = require('../../models/Package');
const { createWalkInOrder, lookupPatient, WalkInError } = require('../../services/walkInOrderService');

const router = express.Router();

function langOf(req) {
    const currentLang = req.cookies?.lang
        || req.headers['accept-language']?.split(',')[0]?.split('-')[0]
        || 'ar';
    return {
        currentLang,
        direction: ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr',
        font: currentLang === 'ar' ? 'Cairo, sans-serif' : 'Inter, sans-serif',
    };
}

router.get('/patients/new', async (req, res) => {
    try {
        const lab = req.lab;
        const packages = await Package.find({ labId: lab._id, isActive: true }).sort({ isMostRequested: -1, createdAt: -1 }).lean();
        const tests = (lab.tests || [])
            .filter((t) => t.isActive !== false)
            .map((t) => ({ _id: String(t._id), name: t.name, nameAr: t.nameAr || '', code: t.code, price: t.price || 0, category: t.category || 'General' }));
        const testIds = new Set(tests.map((t) => t._id));
        const pkgs = packages.map((p) => ({
            _id: String(p._id), name: p.name, nameAr: p.nameAr || '', price: p.price || 0,
            testIds: (p.testIds || []).map(String).filter((id) => testIds.has(id)),
        })).filter((p) => p.testIds.length);

        res.render('dashboard/lab-add-patient', {
            lab,
            user: req.user,
            title: lab.name,
            ...langOf(req),
            activeSection: 'add-patient',
            catalogJson: JSON.stringify({ tests, packages: pkgs }).replace(/</g, '\\u003c'),
        });
    } catch (error) {
        console.error('Add patient page error:', error);
        res.status(500).render('error', { message: 'Error loading page', error: null });
    }
});

router.get('/api/patients/lookup', async (req, res) => {
    try {
        const patient = await lookupPatient(req.lab, req.query.q || req.query.phone);
        res.json({ success: true, data: patient });
    } catch (error) {
        console.error('Patient lookup error:', error);
        res.status(500).json({ success: false, message: 'Lookup failed' });
    }
});

router.post('/api/walk-in-orders', async (req, res) => {
    try {
        const order = await createWalkInOrder(req.lab, req.user._id, req.body || {});
        res.status(201).json({ success: true, data: { orderId: order._id, qrCode: order.qrCode, orderNo: require('../../services/receiptLinkService').receiptCode(order), total: order.pricing.total, patientNo: order.$locals.patientNo ?? null } });
    } catch (error) {
        if (error instanceof WalkInError) {
            return res.status(error.status).json({ success: false, message: error.message });
        }
        console.error('Walk-in order error:', error);
        res.status(500).json({ success: false, message: 'Error creating the order' });
    }
});

module.exports = router;
