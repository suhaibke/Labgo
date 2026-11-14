// The labs' marketplace (products, auctions, labs for sale) and support
// tickets to the LabGo team. Listings stay hidden until the admin approves them.
const express = require('express');
const multer = require('multer');
const mongoose = require('mongoose');
const MarketListing = require('../../models/MarketListing');
const SupportTicket = require('../../models/SupportTicket');
const Counter = require('../../models/Counter');
const r2Service = require('../../services/r2Service');
const market = require('../../services/marketService');
const Banner = require('../../models/Banner');
const AppSettings = require('../../models/AppSettings');

const router = express.Router();
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 8 * 1024 * 1024, files: 6 },
    fileFilter: (req, file, cb) => cb(null, /^image\//.test(file.mimetype)),
});

async function saveImages(files, folder, prefix) {
    const urls = [];
    for (const f of files || []) {
        const name = r2Service.generateUniqueFilename(f.originalname || 'image.jpg', prefix);
        const up = await r2Service.uploadBuffer(f.buffer, r2Service.r2Config.paths[folder], name, { contentType: f.mimetype });
        urls.push(up.url);
    }
    return urls;
}

const num = (v) => {
    const n = Number(String(v ?? '').replace(/[^0-9.]/g, ''));
    return Number.isFinite(n) ? n : 0;
};
const clip = (v, n) => String(v ?? '').trim().slice(0, n);

function view(l, labId) {
    const mine = String(l.labId?._id || l.labId) === String(labId);
    const auction = market.isAuction(l);
    const top = auction ? (l.bids || []).reduce((b, x) => (!b || x.amount > b.amount ? x : b), null) : null;
    return {
        id: String(l._id), kind: l.kind, title: l.title, description: l.description, category: l.category, condition: l.condition,
        code: l.code, price: l.price, stock: l.stock, unit: l.unit, location: l.location, area: l.area, equipment: l.equipment,
        images: l.images || [], approvalStatus: l.approvalStatus, rejectReason: l.rejectReason, status: l.status, mine,
        lab: l.labId?.name ? { name: l.labId.name, city: l.labId.city || '', phone: mine ? l.labId.phone : undefined } : null,
        createdAt: l.createdAt,
        ...(auction ? {
            endsAt: l.endsAt, startedAt: l.reviewedAt || l.createdAt, currentBid: l.currentBid || l.price, bids: (l.bids || []).length,
            topBidder: top ? top.labName : '', youLead: top ? String(top.labId) === String(labId) : false,
            won: l.winnerLabId ? String(l.winnerLabId) === String(labId) : false,
        } : {}),
    };
}

// Approved listings of every lab, plus this lab's own (any status).
router.get('/api/market', async (req, res) => {
    try {
        await market.settleDue();
        const list = await MarketListing.find({
            status: { $ne: 'removed' },
            $or: [{ approvalStatus: 'approved' }, { labId: req.lab._id }],
        }).sort({ createdAt: -1 }).limit(300).populate('labId', 'name city phone').lean();
        // Store banner slides the admin uploaded for the labs' store.
        const [banners, settings] = await Promise.all([
            Banner.find({ isActive: true, placement: 'lab_store' }).sort({ order: 1, createdAt: 1 }).lean().catch(() => []),
            AppSettings.getSingleton().catch(() => null),
        ]);
        res.json({ success: true, data: {
            items: list.map((l) => view(l, req.lab._id)),
            banners: banners.map((b) => ({ id: String(b._id), imageUrl: b.imageUrl })),
            bannerSeconds: settings?.bannerDurationSeconds || 5,
        } });
    } catch (error) {
        console.error('Market list error:', error);
        res.status(500).json({ success: false, message: 'Error loading the store' });
    }
});

router.post('/api/market', upload.array('images', 6), async (req, res) => {
    try {
        const b = req.body || {};
        const kind = MarketListing.KINDS.includes(b.kind) ? b.kind : null;
        if (!kind) return res.status(400).json({ success: false, message: 'Unknown listing type', code: 'kind' });
        const title = clip(b.title, 160);
        if (!title) return res.status(400).json({ success: false, message: 'Name is required', code: 'title' });
        const price = Math.round(num(b.price));
        if (!(price > 0)) return res.status(400).json({ success: false, message: 'Price is required', code: 'price' });
        const doc = {
            labId: req.lab._id, kind, title, price,
            description: clip(b.description, 3000), category: clip(b.category, 40),
            condition: ['New', 'Used'].includes(b.condition) ? b.condition : '',
            code: clip(b.code, 40).toUpperCase(), stock: Math.round(num(b.stock)), unit: clip(b.unit, 20),
            location: clip(b.location, 200), area: clip(b.area, 40), equipment: clip(b.equipment, 600),
            images: await saveImages(req.files, 'market', 'market-'),
        };
        if (kind === 'product' && !(doc.stock > 0)) return res.status(400).json({ success: false, message: 'Quantity is required', code: 'stock' });
        if (market.isAuction(doc)) {
            const days = Math.min(30, Math.max(1, Math.round(num(b.days) || 3)));
            doc.endsAt = new Date(Date.now() + days * 86400000); // reset when approved
            doc.currentBid = price;
            doc.durationDays = days;
        }
        const listing = await MarketListing.create(doc);
        res.status(201).json({ success: true, data: view(listing, req.lab._id) });
    } catch (error) {
        console.error('Market create error:', error);
        res.status(500).json({ success: false, message: 'Error saving' });
    }
});

router.post('/api/market/:id/bid', async (req, res) => {
    try {
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) return res.status(404).json({ success: false });
        const l = await MarketListing.findById(req.params.id);
        if (!l || l.approvalStatus !== 'approved' || !market.isAuction(l)) return res.status(404).json({ success: false, message: 'Not found' });
        await market.settle(l);
        if (l.settledAt || l.endsAt <= new Date()) return res.status(409).json({ success: false, message: 'The auction has ended', code: 'ended' });
        if (String(l.labId) === String(req.lab._id)) return res.status(400).json({ success: false, message: 'You cannot bid on your own auction', code: 'own' });
        const amount = Math.round(num(req.body?.amount));
        const min = (l.currentBid || l.price) + 1;
        if (amount < min) return res.status(400).json({ success: false, message: `The bid must be at least ${min}`, code: 'low', min });
        const updated = await MarketListing.findOneAndUpdate(
            { _id: l._id, currentBid: l.currentBid, settledAt: null },
            { $set: { currentBid: amount }, $push: { bids: { labId: req.lab._id, labName: req.lab.name, amount } } },
            { new: true },
        ).populate('labId', 'name city phone');
        if (!updated) return res.status(409).json({ success: false, message: 'Someone bid at the same time, try again', code: 'race' });
        res.json({ success: true, data: view(updated, req.lab._id) });
    } catch (error) {
        console.error('Market bid error:', error);
        res.status(500).json({ success: false, message: 'Error placing the bid' });
    }
});

router.delete('/api/market/:id', async (req, res) => {
    try {
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) return res.status(404).json({ success: false });
        const r = await MarketListing.updateOne({ _id: req.params.id, labId: req.lab._id, 'bids.0': { $exists: false } }, { $set: { status: 'removed' } });
        if (!r.matchedCount) return res.status(404).json({ success: false, message: 'Not found or already has bids' });
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false });
    }
});

// ---------- support ----------
router.get('/api/support', async (req, res) => {
    try {
        const list = await SupportTicket.find({ labId: req.lab._id }).sort({ createdAt: -1 }).limit(100).lean();
        res.json({ success: true, data: { items: list.map((t) => ({ id: String(t._id), ticketNo: t.ticketNo, type: t.type, subject: t.subject, message: t.message, images: t.images, status: t.status, adminReply: t.adminReply, createdAt: t.createdAt })) } });
    } catch (error) {
        res.status(500).json({ success: false });
    }
});

router.post('/api/support', upload.array('images', 6), async (req, res) => {
    try {
        const b = req.body || {};
        const message = clip(b.message, 4000);
        if (!message) return res.status(400).json({ success: false, message: 'Write your message', code: 'message' });
        const ticket = await SupportTicket.create({
            ticketNo: await Counter.next('supportTicket', 5000),
            labId: req.lab._id, userId: req.user._id,
            type: SupportTicket.TYPES.includes(b.type) ? b.type : 'other',
            subject: clip(b.subject, 160), message,
            images: await saveImages(req.files, 'support', 'support-'),
        });
        res.status(201).json({ success: true, data: { id: String(ticket._id), ticketNo: ticket.ticketNo } });
    } catch (error) {
        console.error('Support create error:', error);
        res.status(500).json({ success: false, message: 'Error sending' });
    }
});

module.exports = router;
module.exports.view = view;
