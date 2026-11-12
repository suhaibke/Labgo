const express = require('express');
const router = express.Router();
const Banner = require('../../models/Banner');
const AppSettings = require('../../models/AppSettings');
const auth = require('../../middleware/auth');
const { r2SingleUpload } = require('../../middleware/r2Upload');
const r2Service = require('../../services/r2Service');

const requireAdmin = async (req, res, next) => {
    if (req.user.role !== 'admin') {
        return res.status(403).json({
            success: false,
            message: 'Access denied. Admin role required.'
        });
    }
    next();
};

const uploadBannerImage = r2SingleUpload('banners', 'image', 'banner-');

// Get all banners (admin view - includes inactive) plus the rotation setting
router.get('/', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const [banners, settings] = await Promise.all([
            Banner.find().sort({ order: 1, createdAt: 1 }),
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
        console.error('List banners error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Update the shared rotation duration (must come before /:id routes)
router.put('/duration', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const seconds = Number(req.body.bannerDurationSeconds);
        if (!Number.isFinite(seconds) || seconds < 2 || seconds > 30) {
            return res.status(400).json({
                success: false,
                message: 'bannerDurationSeconds must be a number between 2 and 30',
            });
        }

        const settings = await AppSettings.getSingleton();
        settings.bannerDurationSeconds = seconds;
        await settings.save();

        res.json({ success: true, data: { bannerDurationSeconds: settings.bannerDurationSeconds } });
    } catch (error) {
        console.error('Update banner duration error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Create a new banner slide
router.post('/', auth.verifyToken, requireAdmin, uploadBannerImage, async (req, res) => {
    try {
        if (!req.file || !req.file.r2Url) {
            return res.status(400).json({ success: false, message: 'image is required' });
        }

        const { order } = req.body;
        const banner = new Banner({
            imageUrl: req.file.r2Url,
            order: order ? Number(order) : 0,
            createdBy: req.user._id,
        });
        await banner.save();

        res.status(201).json({ success: true, data: { banner } });
    } catch (error) {
        console.error('Create banner error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Update a banner (reorder / activate-deactivate / replace image)
router.put('/:id', auth.verifyToken, requireAdmin, uploadBannerImage, async (req, res) => {
    try {
        const banner = await Banner.findById(req.params.id);
        if (!banner) {
            return res.status(404).json({ success: false, message: 'Banner not found' });
        }

        const { order, isActive } = req.body;
        if (order !== undefined) banner.order = Number(order);
        if (isActive !== undefined) banner.isActive = isActive === true || isActive === 'true';

        if (req.file && req.file.r2Url) {
            const oldImage = banner.imageUrl;
            banner.imageUrl = req.file.r2Url;
            if (oldImage) {
                await r2Service.deleteFile(oldImage).catch(() => {});
            }
        }

        await banner.save();
        res.json({ success: true, data: { banner } });
    } catch (error) {
        console.error('Update banner error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Delete a banner
router.delete('/:id', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const banner = await Banner.findById(req.params.id);
        if (!banner) {
            return res.status(404).json({ success: false, message: 'Banner not found' });
        }
        if (banner.imageUrl) {
            await r2Service.deleteFile(banner.imageUrl).catch(() => {});
        }
        await banner.deleteOne();
        res.json({ success: true });
    } catch (error) {
        console.error('Delete banner error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

module.exports = router;
