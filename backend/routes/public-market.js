// The labs' store for someone browsing the lab app as a guest: approved
// listings only, read-only, no seller contact details. Buying, bidding and
// listing need a lab account (the /lab/api/market routes).
const express = require('express');
const MarketListing = require('../models/MarketListing');
const Banner = require('../models/Banner');
const AppSettings = require('../models/AppSettings');
const market = require('../services/marketService');
const { view } = require('./lab/market-support');

const router = express.Router();

router.get('/api/public/market', async (req, res) => {
    try {
        await market.settleDue();
        const list = await MarketListing.find({ status: { $ne: 'removed' }, approvalStatus: 'approved' })
            .sort({ createdAt: -1 }).limit(300).populate('labId', 'name city').lean();
        const [banners, settings] = await Promise.all([
            Banner.find({ isActive: true, placement: 'lab_store' }).sort({ order: 1, createdAt: 1 }).lean().catch(() => []),
            AppSettings.getSingleton().catch(() => null),
        ]);
        res.set('Cache-Control', 'public, max-age=60');
        res.json({ success: true, data: {
            items: list.map((l) => view(l, null)),
            banners: banners.map((b) => ({ id: String(b._id), imageUrl: b.imageUrl, linkUrl: b.linkUrl || '' })),
            bannerSeconds: settings?.bannerDurationSeconds || 5,
            guest: true,
        } });
    } catch (error) {
        console.error('Public market error:', error);
        res.status(500).json({ success: false, message: 'Error loading the store' });
    }
});

module.exports = router;
