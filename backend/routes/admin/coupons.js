const express = require('express');
const router = express.Router();
const Coupon = require('../../models/Coupon');
const auth = require('../../middleware/auth');

const requireAdmin = async (req, res, next) => {
    if (req.user.role !== 'admin') {
        return res.status(403).json({
            success: false,
            message: 'Access denied. Admin role required.'
        });
    }
    next();
};

// List coupons, newest first
router.get('/', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { search } = req.query;
        const filter = {};
        if (search) {
            filter.code = { $regex: search, $options: 'i' };
        }
        const coupons = await Coupon.find(filter).sort({ createdAt: -1 });
        res.json({ success: true, data: { coupons } });
    } catch (error) {
        console.error('List coupons error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Create a coupon
router.post('/', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const {
            code, discountType, discountValue,
            minOrderAmount, maxDiscount,
            usageLimit, usageLimitPerUser,
            startDate, endDate, isActive
        } = req.body;

        if (!code || !discountType || discountValue === undefined) {
            return res.status(400).json({
                success: false,
                message: 'Code, discount type, and discount value are required'
            });
        }
        if (discountType === 'percentage' && (discountValue < 0 || discountValue > 100)) {
            return res.status(400).json({
                success: false,
                message: 'Percentage discount must be between 0 and 100'
            });
        }

        const existing = await Coupon.findOne({ code: code.trim().toUpperCase() });
        if (existing) {
            return res.status(400).json({ success: false, message: 'This code is already in use' });
        }

        const coupon = new Coupon({
            code: code.trim().toUpperCase(),
            discountType,
            discountValue,
            minOrderAmount: minOrderAmount || 0,
            maxDiscount: maxDiscount || 0,
            usageLimit: usageLimit || null,
            usageLimitPerUser: usageLimitPerUser || null,
            startDate: startDate || new Date(),
            endDate: endDate || null,
            isActive: isActive !== undefined ? isActive : true,
            createdBy: req.user.id,
        });
        await coupon.save();

        res.status(201).json({ success: true, message: 'Coupon created successfully', data: { coupon } });
    } catch (error) {
        console.error('Create coupon error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Get a single coupon
router.get('/:id', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const coupon = await Coupon.findById(req.params.id);
        if (!coupon) {
            return res.status(404).json({ success: false, message: 'Coupon not found' });
        }
        res.json({ success: true, data: { coupon } });
    } catch (error) {
        console.error('Get coupon error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Update a coupon
router.put('/:id', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const coupon = await Coupon.findById(req.params.id);
        if (!coupon) {
            return res.status(404).json({ success: false, message: 'Coupon not found' });
        }

        const updates = req.body;
        if (updates.code !== undefined) {
            const newCode = updates.code.trim().toUpperCase();
            if (newCode !== coupon.code) {
                const existing = await Coupon.findOne({ code: newCode, _id: { $ne: coupon._id } });
                if (existing) {
                    return res.status(400).json({ success: false, message: 'This code is already in use' });
                }
            }
            coupon.code = newCode;
        }

        const allowedUpdates = [
            'discountType', 'discountValue',
            'minOrderAmount', 'maxDiscount',
            'usageLimit', 'usageLimitPerUser',
            'startDate', 'endDate', 'isActive'
        ];
        allowedUpdates.forEach((field) => {
            if (updates[field] !== undefined) {
                coupon[field] = updates[field];
            }
        });

        await coupon.save();
        res.json({ success: true, message: 'Coupon updated successfully', data: { coupon } });
    } catch (error) {
        console.error('Update coupon error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Delete a coupon
router.delete('/:id', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const coupon = await Coupon.findById(req.params.id);
        if (!coupon) {
            return res.status(404).json({ success: false, message: 'Coupon not found' });
        }
        await coupon.deleteOne();
        res.json({ success: true, message: 'Coupon deleted successfully' });
    } catch (error) {
        console.error('Delete coupon error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Toggle active status
router.patch('/:id/toggle', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const coupon = await Coupon.findById(req.params.id);
        if (!coupon) {
            return res.status(404).json({ success: false, message: 'Coupon not found' });
        }
        coupon.isActive = !coupon.isActive;
        await coupon.save();
        res.json({
            success: true,
            message: `Coupon ${coupon.isActive ? 'activated' : 'deactivated'} successfully`,
            data: { coupon }
        });
    } catch (error) {
        console.error('Toggle coupon error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

module.exports = router;
