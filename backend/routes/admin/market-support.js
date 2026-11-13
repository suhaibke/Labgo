// LabGo admin: review marketplace listings and answer support tickets.
const express = require('express');
const mongoose = require('mongoose');
const auth = require('../../middleware/auth');
const MarketListing = require('../../models/MarketListing');
const SupportTicket = require('../../models/SupportTicket');
const { notifyLab } = require('../../services/labNotify');

const router = express.Router();
const requireAdmin = (req, res, next) => (req.user?.role === 'admin' ? next() : res.status(403).json({ success: false, message: 'Admin role required' }));
router.use(auth.verifyToken, requireAdmin);
const valid = (id) => mongoose.Types.ObjectId.isValid(id);

const KIND_AR = { product: 'منتج', auction: 'مزاد', lab_sale: 'مختبر للبيع', lab_auction: 'مختبر في المزاد' };

router.get('/market', async (req, res) => {
    try {
        const filter = { status: { $ne: 'removed' } };
        if (['pending', 'approved', 'rejected'].includes(req.query.status)) filter.approvalStatus = req.query.status;
        const [items, pending] = await Promise.all([
            MarketListing.find(filter).sort({ createdAt: -1 }).limit(300).populate('labId', 'name city phone').lean(),
            MarketListing.countDocuments({ approvalStatus: 'pending', status: { $ne: 'removed' } }),
        ]);
        res.json({ success: true, data: { pending, items } });
    } catch (error) {
        res.status(500).json({ success: false });
    }
});

router.patch('/market/:id', async (req, res) => {
    try {
        if (!valid(req.params.id)) return res.status(404).json({ success: false });
        const l = await MarketListing.findById(req.params.id);
        if (!l) return res.status(404).json({ success: false });
        const approve = req.body?.action === 'approve';
        l.approvalStatus = approve ? 'approved' : 'rejected';
        l.rejectReason = approve ? '' : String(req.body?.reason || '').slice(0, 300);
        l.reviewedAt = new Date();
        // An auction runs from the moment it is approved.
        if (approve && (l.kind === 'auction' || l.kind === 'lab_auction')) l.endsAt = new Date(Date.now() + (l.durationDays || 3) * 86400000);
        await l.save();
        await notifyLab(l.labId, {
            title: approve ? `تمت الموافقة: ${l.title}` : `لم تتم الموافقة: ${l.title}`,
            body: approve ? `${KIND_AR[l.kind]} معروض الآن في متجر LabGo.` : (l.rejectReason || 'راجع البيانات وأعد الإرسال.'),
            data: { type: approve ? 'market_approved' : 'market_rejected', listingId: String(l._id) },
        });
        res.json({ success: true });
    } catch (error) {
        console.error('Admin market review error:', error);
        res.status(500).json({ success: false });
    }
});

router.get('/support', async (req, res) => {
    try {
        const filter = {};
        if (['open', 'in_progress', 'closed'].includes(req.query.status)) filter.status = req.query.status;
        const [items, unseen] = await Promise.all([
            SupportTicket.find(filter).sort({ createdAt: -1 }).limit(300).populate('labId', 'name city phone').populate('userId', 'name phone').lean(),
            SupportTicket.countDocuments({ adminSeenAt: null }),
        ]);
        res.json({ success: true, data: { unseen, items } });
    } catch (error) {
        res.status(500).json({ success: false });
    }
});

router.get('/counts', async (req, res) => {
    try {
        const [support, market] = await Promise.all([
            SupportTicket.countDocuments({ adminSeenAt: null }),
            MarketListing.countDocuments({ approvalStatus: 'pending', status: { $ne: 'removed' } }),
        ]);
        res.json({ success: true, data: { support, market } });
    } catch (error) {
        res.status(500).json({ success: false });
    }
});

router.post('/support/seen', async (req, res) => {
    try {
        await SupportTicket.updateMany({ adminSeenAt: null }, { $set: { adminSeenAt: new Date() } });
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false });
    }
});

router.patch('/support/:id', async (req, res) => {
    try {
        if (!valid(req.params.id)) return res.status(404).json({ success: false });
        const t = await SupportTicket.findById(req.params.id);
        if (!t) return res.status(404).json({ success: false });
        if (['open', 'in_progress', 'closed'].includes(req.body?.status)) t.status = req.body.status;
        if (typeof req.body?.reply === 'string' && req.body.reply.trim()) t.adminReply = req.body.reply.trim().slice(0, 4000);
        await t.save();
        if (req.body?.reply) {
            await notifyLab(t.labId, { title: `رد على البلاغ #${t.ticketNo}`, body: t.adminReply.slice(0, 180), data: { type: 'support_reply', ticketId: String(t._id) } });
        }
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false });
    }
});

module.exports = router;
