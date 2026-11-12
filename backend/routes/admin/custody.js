const express = require('express');
const router = express.Router();
const QRCode = require('qrcode');
const CustodyItem = require('../../models/CustodyItem');
const CustodyRequest = require('../../models/CustodyRequest');
const User = require('../../models/User');
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

// ==================== INVENTORY (physical units) ====================

// Get all custody units, with optional filters
router.get('/items', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { category, status, search } = req.query;
        const query = {};
        if (category) query.category = category;
        if (status) query.status = status;
        if (search) {
            query.$or = [
                { name: new RegExp(search, 'i') },
                { code: new RegExp(search, 'i') },
                { serialNumber: new RegExp(search, 'i') },
            ];
        }

        const items = await CustodyItem.find(query)
            .populate('currentHolder', 'name phone')
            .sort({ createdAt: -1 });

        res.json({ success: true, data: { items } });
    } catch (error) {
        console.error('List custody items error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Get a single custody unit, with its QR code
router.get('/items/:id', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const item = await CustodyItem.findById(req.params.id).populate('currentHolder', 'name phone');
        if (!item) {
            return res.status(404).json({ success: false, message: 'Custody item not found' });
        }
        const qrDataUrl = await QRCode.toDataURL(item.code, { width: 300, margin: 1 });
        res.json({ success: true, data: { item, qrDataUrl } });
    } catch (error) {
        console.error('Get custody item error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Create new custody units. `quantity` physical units are created, each
// with its own unique auto-generated barcode.
router.post('/items', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { name, category, serialNumber, quantity, value, receivedFrom, notes } = req.body;

        if (!name || !category) {
            return res.status(400).json({ success: false, message: 'name and category are required' });
        }

        const unitCount = Math.max(1, Number(quantity) || 1);
        const units = [];
        for (let i = 0; i < unitCount; i++) {
            units.push({
                name,
                category,
                serialNumber: unitCount > 1 && serialNumber ? `${serialNumber}-${i + 1}` : serialNumber,
                value: value || 0,
                receivedFrom,
                notes,
            });
        }
        const created = await CustodyItem.insertMany(units);

        res.status(201).json({ success: true, data: { items: created } });
    } catch (error) {
        console.error('Create custody item error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Update a custody unit's editable fields
router.put('/items/:id', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const item = await CustodyItem.findById(req.params.id);
        if (!item) {
            return res.status(404).json({ success: false, message: 'Custody item not found' });
        }

        const { name, category, serialNumber, value, receivedFrom, notes, status } = req.body;
        if (name !== undefined) item.name = name;
        if (category !== undefined) item.category = category;
        if (serialNumber !== undefined) item.serialNumber = serialNumber;
        if (value !== undefined) item.value = value;
        if (receivedFrom !== undefined) item.receivedFrom = receivedFrom;
        if (notes !== undefined) item.notes = notes;
        // Manual status override (e.g. marking needs_maintenance) only allowed
        // when the item isn't currently checked out to a nurse.
        if (status !== undefined && !item.currentHolder) item.status = status;

        await item.save();
        res.json({ success: true, data: { item } });
    } catch (error) {
        console.error('Update custody item error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Catalog view: distinct item names grouped with available/total counts
router.get('/catalog', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const catalog = await CustodyItem.aggregate([
            {
                $group: {
                    _id: { name: '$name', category: '$category' },
                    total: { $sum: 1 },
                    available: { $sum: { $cond: [{ $eq: ['$status', 'available'] }, 1, 0] } },
                },
            },
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
        console.error('Custody catalog error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// ==================== REQUESTS (request -> approve -> deliver -> return) ====================

// List requests, filterable by status
router.get('/requests', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { status } = req.query;
        const query = {};
        if (status) query.status = status;

        const requests = await CustodyRequest.find(query)
            .populate('nurseId', 'name phone')
            .populate('itemId', 'name code status')
            .sort({ createdAt: -1 });

        res.json({ success: true, data: { requests } });
    } catch (error) {
        console.error('List custody requests error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Available units matching a pending request's item name, for the admin to
// pick from when approving
router.get('/requests/:id/available-units', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const request = await CustodyRequest.findById(req.params.id);
        if (!request) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }
        const units = await CustodyItem.find({ name: request.itemName, status: 'available' });
        res.json({ success: true, data: { units } });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Approve a request, assigning it to a specific available unit
router.post('/requests/:id/approve', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { itemId } = req.body;
        if (!itemId) {
            return res.status(400).json({ success: false, message: 'itemId is required' });
        }

        const request = await CustodyRequest.findById(req.params.id);
        if (!request) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }
        if (request.status !== 'pending') {
            return res.status(400).json({ success: false, message: 'Request has already been reviewed' });
        }

        const unit = await CustodyItem.findById(itemId);
        if (!unit || unit.status !== 'available') {
            return res.status(400).json({ success: false, message: 'Selected unit is not available' });
        }

        await request.approve(req.user.id, itemId);
        res.json({ success: true, data: { request } });
    } catch (error) {
        console.error('Approve custody request error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Reject a request
router.post('/requests/:id/reject', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const request = await CustodyRequest.findById(req.params.id);
        if (!request) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }
        if (request.status !== 'pending') {
            return res.status(400).json({ success: false, message: 'Request has already been reviewed' });
        }
        await request.reject(req.user.id, req.body.reason);
        res.json({ success: true, data: { request } });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Confirm delivery: admin scans the assigned unit's own barcode
router.post('/requests/:id/deliver', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { scannedCode } = req.body;
        const request = await CustodyRequest.findById(req.params.id);
        if (!request) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }
        if (request.status !== 'approved') {
            return res.status(400).json({ success: false, message: 'Request is not awaiting delivery' });
        }

        const unit = await CustodyItem.findById(request.itemId);
        if (!unit) {
            return res.status(404).json({ success: false, message: 'Assigned unit not found' });
        }
        if (!scannedCode || scannedCode !== unit.code) {
            return res.status(400).json({ success: false, message: 'Scanned code does not match the assigned item' });
        }

        unit.status = 'in_use';
        unit.currentHolder = request.nurseId;
        await unit.save();

        await request.markDelivered(req.user.id);
        res.json({ success: true, data: { request } });
    } catch (error) {
        console.error('Deliver custody request error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Confirm return: admin scans the return code shown on the nurse's phone
router.post('/requests/:id/confirm-return', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { scannedCode } = req.body;
        const request = await CustodyRequest.findById(req.params.id);
        if (!request) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }
        if (request.status !== 'return_requested') {
            return res.status(400).json({ success: false, message: 'Request is not awaiting return confirmation' });
        }
        if (!scannedCode || scannedCode !== request.returnCode) {
            return res.status(400).json({ success: false, message: 'Scanned code does not match this return request' });
        }

        const unit = await CustodyItem.findById(request.itemId);
        if (unit) {
            unit.status = 'available';
            unit.currentHolder = null;
            await unit.save();
        }

        await request.confirmReturn(req.user.id);
        res.json({ success: true, data: { request } });
    } catch (error) {
        console.error('Confirm return custody request error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Nurses list, kept for reference/manual lookups in the dashboard
router.get('/nurses', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const nurses = await User.find({ role: 'nurse', status: { $ne: 'blocked' } })
            .select('name phone city')
            .sort({ name: 1 });
        res.json({ success: true, data: { nurses } });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

module.exports = router;
