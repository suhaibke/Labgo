const express = require('express');
const router = express.Router();
const Service = require('../../models/Service');
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

const uploadIcon = r2SingleUpload('serviceIcons', 'icon', 'service-');

// Get all services (admin view - includes inactive)
router.get('/', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const services = await Service.find().sort({ order: 1, createdAt: 1 });
        res.json({ success: true, data: { services } });
    } catch (error) {
        console.error('List services error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Create a new service
router.post('/', auth.verifyToken, requireAdmin, uploadIcon, async (req, res) => {
    try {
        const { name, nameAr, nameKu, subtitle, order } = req.body;

        if (!name) {
            return res.status(400).json({ success: false, message: 'name is required' });
        }
        if (!req.file || !req.file.r2Url) {
            return res.status(400).json({ success: false, message: 'icon image is required' });
        }

        const service = new Service({
            name,
            nameAr,
            nameKu,
            subtitle,
            icon: req.file.r2Url,
            order: order ? Number(order) : 0,
        });
        await service.save();

        res.status(201).json({ success: true, data: { service } });
    } catch (error) {
        console.error('Create service error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Update a service (icon replacement optional)
router.put('/:id', auth.verifyToken, requireAdmin, uploadIcon, async (req, res) => {
    try {
        const service = await Service.findById(req.params.id);
        if (!service) {
            return res.status(404).json({ success: false, message: 'Service not found' });
        }

        const { name, nameAr, nameKu, subtitle, order, isActive } = req.body;
        if (name !== undefined) service.name = name;
        if (nameAr !== undefined) service.nameAr = nameAr;
        if (nameKu !== undefined) service.nameKu = nameKu;
        if (subtitle !== undefined) service.subtitle = subtitle;
        if (order !== undefined) service.order = Number(order);
        if (isActive !== undefined) service.isActive = isActive === true || isActive === 'true';

        if (req.file && req.file.r2Url) {
            const oldIcon = service.icon;
            service.icon = req.file.r2Url;
            if (oldIcon) {
                await r2Service.deleteFile(oldIcon).catch(() => {});
            }
        }

        await service.save();
        res.json({ success: true, data: { service } });
    } catch (error) {
        console.error('Update service error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Delete a service
router.delete('/:id', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const service = await Service.findById(req.params.id);
        if (!service) {
            return res.status(404).json({ success: false, message: 'Service not found' });
        }
        if (service.icon) {
            await r2Service.deleteFile(service.icon).catch(() => {});
        }
        await service.deleteOne();
        res.json({ success: true });
    } catch (error) {
        console.error('Delete service error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

module.exports = router;
