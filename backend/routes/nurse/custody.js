const express = require('express');
const router = express.Router();
const CustodyItem = require('../../models/CustodyItem');
const CustodyRequest = require('../../models/CustodyRequest');
const { verifyToken } = require('../../middleware/auth');

const nurseOnly = (req, res, next) => {
    if (req.userRole !== 'nurse') {
        return res.status(403).json({
            success: false,
            message: 'Access denied. Nurse role required.'
        });
    }
    next();
};

// Browse the custody catalog (item names grouped with available counts)
router.get('/catalog', verifyToken, nurseOnly, async (req, res) => {
    try {
        const catalog = await CustodyItem.aggregate([
            {
                $group: {
                    _id: { name: '$name', category: '$category' },
                    total: { $sum: 1 },
                    available: { $sum: { $cond: [{ $eq: ['$status', 'available'] }, 1, 0] } },
                },
            },
            { $match: { available: { $gt: 0 } } },
            { $sort: { '_id.name': 1 } },
        ]);

        res.json({
            success: true,
            data: {
                catalog: catalog.map((c) => ({
                    name: c._id.name,
                    category: c._id.category,
                    total: c.total,
                    available: c.available,
                })),
            },
        });
    } catch (error) {
        console.error('Nurse custody catalog error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Request a custody item by name, with an expected duration
router.post('/requests', verifyToken, nurseOnly, async (req, res) => {
    try {
        const { itemName, requestedDurationDays, notes } = req.body;

        if (!itemName || !requestedDurationDays) {
            return res.status(400).json({
                success: false,
                message: 'itemName and requestedDurationDays are required',
            });
        }

        const availableCount = await CustodyItem.countDocuments({ name: itemName, status: 'available' });
        if (availableCount === 0) {
            return res.status(400).json({ success: false, message: 'No units of this item are currently available' });
        }

        const request = new CustodyRequest({
            nurseId: req.user.id,
            itemName,
            requestedDurationDays,
            notes,
        });
        await request.save();

        res.status(201).json({ success: true, data: { request } });
    } catch (error) {
        console.error('Create custody request error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Get the logged-in nurse's own requests
router.get('/requests', verifyToken, nurseOnly, async (req, res) => {
    try {
        const requests = await CustodyRequest.find({ nurseId: req.user.id })
            .populate('itemId', 'name code')
            .sort({ createdAt: -1 });
        res.json({ success: true, data: { requests } });
    } catch (error) {
        console.error('Get nurse custody requests error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Initiate a return: generates a one-time return code to show the admin
router.post('/requests/:id/initiate-return', verifyToken, nurseOnly, async (req, res) => {
    try {
        const request = await CustodyRequest.findById(req.params.id);
        if (!request) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }
        if (String(request.nurseId) !== String(req.user.id)) {
            return res.status(403).json({ success: false, message: 'This request does not belong to you' });
        }
        if (request.status !== 'delivered') {
            return res.status(400).json({ success: false, message: 'This item is not currently in your custody' });
        }

        await request.initiateReturn();
        res.json({ success: true, data: { request } });
    } catch (error) {
        console.error('Initiate custody return error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

module.exports = router;
