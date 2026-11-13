// Medical waste: collection requests and their log.
const express = require('express');
const LabWaste = require('../../models/LabWaste');

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

async function listFor(labId) {
    const items = await LabWaste.find({ labId }).sort({ status: -1, pickupDate: -1 }).limit(300).lean();
    const since = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
    const totals = { pending: 0, monthKg: 0, byType: {} };
    for (const w of items) {
        if (w.status === 'pending') totals.pending += 1;
        if (w.status === 'collected' && new Date(w.collectedAt || w.pickupDate) >= since) {
            totals.monthKg += w.weightKg;
            totals.byType[w.type] = (totals.byType[w.type] || 0) + w.weightKg;
        }
    }
    totals.monthKg = Math.round(totals.monthKg * 100) / 100;
    return { items, totals };
}

router.get('/waste', async (req, res) => {
    try {
        res.render('dashboard/lab-waste', {
            lab: req.lab,
            user: req.user,
            title: req.lab.name,
            ...langOf(req),
            activeSection: 'waste',
            types: LabWaste.TYPES,
            dataJson: JSON.stringify(await listFor(req.lab._id)).replace(/</g, '\\u003c'),
        });
    } catch (error) {
        console.error('Waste page error:', error);
        res.status(500).render('error', { message: 'Error loading waste', error: null });
    }
});

router.get('/api/waste', async (req, res) => {
    try {
        res.json({ success: true, data: await listFor(req.lab._id) });
    } catch (error) {
        console.error('Waste list error:', error);
        res.status(500).json({ success: false, message: 'Error loading waste' });
    }
});

router.post('/api/waste', async (req, res) => {
    try {
        const { type, weightKg, pickupDate, company, notes } = req.body || {};
        if (!LabWaste.TYPES.includes(type)) return res.status(400).json({ success: false, message: 'Choose the waste type', code: 'type' });
        const weight = Math.round(Number(weightKg) * 100) / 100;
        if (!Number.isFinite(weight) || weight <= 0) return res.status(400).json({ success: false, message: 'Enter the weight', code: 'weight' });
        const date = pickupDate ? new Date(pickupDate) : new Date();
        if (Number.isNaN(date.getTime())) return res.status(400).json({ success: false, message: 'Invalid date', code: 'date' });
        const item = await LabWaste.create({
            labId: req.lab._id, type, weightKg: weight, pickupDate: date,
            company: String(company || '').trim().slice(0, 120), notes: String(notes || '').trim().slice(0, 500),
            createdBy: req.user._id,
        });
        res.status(201).json({ success: true, data: item });
    } catch (error) {
        console.error('Waste create error:', error);
        res.status(500).json({ success: false, message: 'Error saving the request' });
    }
});

router.patch('/api/waste/:id/collected', async (req, res) => {
    try {
        const item = await LabWaste.findOneAndUpdate(
            { _id: req.params.id, labId: req.lab._id },
            { status: 'collected', collectedAt: new Date() },
            { new: true }
        );
        if (!item) return res.status(404).json({ success: false, message: 'Request not found' });
        res.json({ success: true, data: item });
    } catch (error) {
        console.error('Waste collected error:', error);
        res.status(500).json({ success: false, message: 'Error updating the request' });
    }
});

router.delete('/api/waste/:id', async (req, res) => {
    try {
        const result = await LabWaste.deleteOne({ _id: req.params.id, labId: req.lab._id, status: 'pending' });
        if (!result.deletedCount) return res.status(404).json({ success: false, message: 'Only pending requests can be deleted' });
        res.json({ success: true });
    } catch (error) {
        console.error('Waste delete error:', error);
        res.status(500).json({ success: false, message: 'Error deleting the request' });
    }
});

module.exports = router;
