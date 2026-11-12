const express = require('express');
const router = express.Router();
const Banner = require('../../models/Banner');
const AppSettings = require('../../models/AppSettings');

/**
 * GET /api/app/banners
 * Active home page banner slides, in display order, plus the shared
 * rotation duration.
 */
router.get('/', async (req, res) => {
    try {
        const [banners, settings] = await Promise.all([
            Banner.find({ isActive: true }).sort({ order: 1, createdAt: 1 }),
            AppSettings.getSingleton(),
        ]);

        res.json({
            success: true,
            data: {
                banners,
                bannerDurationSeconds: settings.bannerDurationSeconds,
            },
        });
    } catch (error) {
        console.error('Get banners error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

module.exports = router;
