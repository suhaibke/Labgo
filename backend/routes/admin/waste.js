// Medical waste pickup requests from every lab, for the LabGo admin panel.
const express = require('express');
const mongoose = require('mongoose');
const auth = require('../../middleware/auth');
const LabWaste = require('../../models/LabWaste');
const Lab = require('../../models/Lab');
const wasteReport = require('../../services/wasteReportService');

const router = express.Router();
const requireAdmin = (req, res, next) => (req.user?.role === 'admin' ? next() : res.status(403).json({ success: false, message: 'Admin role required' }));
router.use(auth.verifyToken, requireAdmin);

// List (newest first) and the number of requests the admin has not seen yet.
router.get('/', async (req, res) => {
    try {
        const filter = {};
        if (req.query.status === 'pending' || req.query.status === 'collected') filter.status = req.query.status;
        const [items, unseen] = await Promise.all([
            LabWaste.find(filter).sort({ createdAt: -1 }).limit(300).populate('labId', 'name phone address city').lean(),
            LabWaste.countDocuments({ adminSeenAt: null }),
        ]);
        res.json({
            success: true,
            data: {
                unseen,
                items: items.map((w) => ({
                    id: String(w._id), requestNo: w.requestNo || null, type: w.type, weightKg: w.weightKg,
                    pickupDate: w.pickupDate, createdAt: w.createdAt, notes: w.notes, status: w.status, collectedAt: w.collectedAt || null,
                    seen: Boolean(w.adminSeenAt),
                    lab: w.labId ? { id: String(w.labId._id), name: w.labId.name, phone: w.labId.phone, address: w.labId.address, city: w.labId.city } : null,
                })),
            },
        });
    } catch (error) {
        console.error('Admin waste list error:', error);
        res.status(500).json({ success: false, message: 'Error loading requests' });
    }
});

router.get('/unseen-count', async (req, res) => {
    try {
        res.json({ success: true, data: { unseen: await LabWaste.countDocuments({ adminSeenAt: null }) } });
    } catch (error) {
        res.status(500).json({ success: false });
    }
});

router.post('/seen', async (req, res) => {
    try {
        const ids = Array.isArray(req.body?.ids) ? req.body.ids.filter((id) => mongoose.Types.ObjectId.isValid(id)) : null;
        await LabWaste.updateMany(ids ? { _id: { $in: ids }, adminSeenAt: null } : { adminSeenAt: null }, { $set: { adminSeenAt: new Date() } });
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false });
    }
});

// Marks a request collected (the pickup flow is handled by LabGo).
router.patch('/:id/collected', async (req, res) => {
    try {
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) return res.status(404).json({ success: false });
        const item = await LabWaste.findByIdAndUpdate(req.params.id, { $set: { status: 'collected', collectedAt: new Date(), adminSeenAt: new Date() } }, { new: true });
        if (!item) return res.status(404).json({ success: false });
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false });
    }
});

router.get('/:id/report.pdf', async (req, res) => {
    try {
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) return res.status(404).end();
        const item = await LabWaste.findById(req.params.id);
        if (!item) return res.status(404).end();
        const lab = await Lab.findById(item.labId).select('name phone address city logo');
        const pdf = await wasteReport.wasteReportPdf(item, lab);
        res.set('Content-Type', 'application/pdf');
        res.set('Content-Disposition', `inline; filename="waste-request-${item.requestNo || item._id}.pdf"`);
        res.send(pdf);
    } catch (error) {
        if (error.code === 'pdfUnavailable') return res.status(503).json({ success: false, code: 'pdfUnavailable' });
        console.error('Admin waste report error:', error);
        res.status(500).json({ success: false });
    }
});

module.exports = router;
