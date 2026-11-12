const express = require('express');
const router = express.Router();
const Order = require('../models/Order');
const User = require('../models/User');
const Lab = require('../models/Lab');
const Transaction = require('../models/Transaction');
const auth = require('../middleware/auth');
const fcmService = require('../services/fcmService');
const { pickNurseMapLocation } = require('../helpers/nurseLocation');

// Middleware to check if user is a nurse
const isNurse = (req, res, next) => {
    if (req.user.role !== 'nurse') {
        return res.status(403).json({
            success: false,
            message: 'Access denied. Nurse role required.'
        });
    }
    next();
};

// Update nurse's live GPS location (called periodically by the nurse app while on an active order)
router.post('/location', auth.verifyToken, isNurse, async (req, res) => {
    try {
        const { latitude, longitude } = req.body;
        const lat = Number(latitude);
        const lng = Number(longitude);

        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
            return res.status(400).json({
                success: false,
                message: 'latitude and longitude are required numbers'
            });
        }

        const loc = { latitude: lat, longitude: lng, updatedAt: new Date() };
        await User.findByIdAndUpdate(req.user.id, { currentLocation: loc });
        await Order.updateMany(
            { nurseId: req.user.id, status: 'nurse_assigned' },
            { nurseMapLocation: loc }
        );

        res.json({ success: true });
    } catch (error) {
        console.error('Update nurse location error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get available confirmed orders for nurses to accept (filtered by nurse's city)
router.get('/available-orders', auth.verifyToken, isNurse, async (req, res) => {
    try {
        const nurseId = req.user.id;
        const { status = 'confirmed', page = 1, limit = 20 } = req.query;

        // Get nurse's city
        const nurse = await User.findById(nurseId).select('city');
        if (!nurse) {
            return res.status(404).json({
                success: false,
                message: 'Nurse not found'
            });
        }

        // Build base query
        const query = {
            status: status,
            nurseId: null // Only orders not yet assigned to a nurse
        };

        // If nurse has a city set, filter orders by labs in that city
        if (nurse.city) {
            const labsInCity = await Lab.find({ city: nurse.city }).select('_id');
            const labIds = labsInCity.map(lab => lab._id);
            query.labId = { $in: labIds };
        }

        const orders = await Order.find(query)
            .populate('patientId', 'name phone email birthDate')
            .populate('labId', 'name address phone city coordinates')
            .sort({ createdAt: -1 })
            .limit(parseInt(limit))
            .skip((parseInt(page) - 1) * parseInt(limit));

        const total = await Order.countDocuments(query);

        res.json({
            success: true,
            data: {
                orders: orders,
                total: total,
                page: parseInt(page),
                pages: Math.ceil(total / parseInt(limit)),
                nurseCity: nurse.city || null
            }
        });
    } catch (error) {
        console.error('Get available orders error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get orders assigned to this nurse
router.get('/my-orders', auth.verifyToken, isNurse, async (req, res) => {
    try {
        const nurseId = req.user.id;
        const { status, page = 1, limit = 20 } = req.query;

        const query = { nurseId: nurseId };
        if (status) {
            // Handle "in_progress" filter which includes all active statuses for nurse
            if (status === 'in_progress') {
                query.status = {
                    $in: ['nurse_assigned', 'sample_collected']
                };
            } else {
                query.status = status;
            }
        }

        const orders = await Order.find(query)
            .populate('patientId', 'name phone email birthDate')
            .populate('labId', 'name address phone city coordinates')
            .sort({ createdAt: -1 })
            .limit(parseInt(limit))
            .skip((parseInt(page) - 1) * parseInt(limit));

        const total = await Order.countDocuments(query);

        res.json({
            success: true,
            data: {
                orders: orders,
                total: total,
                page: parseInt(page),
                pages: Math.ceil(total / parseInt(limit))
            }
        });
    } catch (error) {
        console.error('Get nurse orders error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get order details for nurse
router.get('/order/:orderId', auth.verifyToken, isNurse, async (req, res) => {
    try {
        const { orderId } = req.params;
        const nurseId = req.user.id;

        const order = await Order.findById(orderId)
            .populate('patientId', 'name phone email birthDate gender')
            .populate('labId', 'name address phone email city country coordinates')
            .populate('nurseId', 'name phone');

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Check if nurse is assigned to this order or if order is available (confirmed status with no nurse)
        const isAssigned = order.nurseId && order.nurseId._id.toString() === nurseId.toString();
        const isAvailable = order.status === 'confirmed' && !order.nurseId;

        if (!isAssigned && !isAvailable) {
            return res.status(403).json({
                success: false,
                message: 'Access denied'
            });
        }

        res.json({
            success: true,
            data: {
                order: order
            }
        });
    } catch (error) {
        console.error('Get nurse order details error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Accept/Confirm order (nurse accepts assignment)
router.post('/order/:orderId/accept', auth.verifyToken, isNurse, async (req, res) => {
    try {
        const { orderId } = req.params;
        const nurseId = req.user.id;
        const { estimatedArrival } = req.body;

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Can only accept confirmed orders that are not already assigned
        if (order.status !== 'confirmed' || order.nurseId) {
            return res.status(400).json({
                success: false,
                message: 'Order is not available for acceptance'
            });
        }

        // Accept the order
        await order.nurseAcceptOrder(
            nurseId,
            estimatedArrival ? new Date(estimatedArrival) : null
        );
        const nurseUser = await User.findById(nurseId).select('currentLocation defaultLocation name');
        const snapshot = pickNurseMapLocation(nurseUser);
        if (snapshot) {
            order.nurseMapLocation = snapshot;
            await order.save();
        }

        // Return updated order with populated fields
        const updatedOrder = await Order.findById(orderId)
            .populate('patientId', 'name phone email birthDate')
            .populate('labId', 'name address phone city coordinates')
            .populate('nurseId', 'name phone');

        // Send FCM notification to patient
        try {
            const nurse = await User.findById(nurseId).select('name');
            await fcmService.sendToUser(
                order.patientId._id || order.patientId,
                'تم تعيين ممرض/ة',
                `تم تعيين ${nurse?.name || 'ممرض/ة'} لطلبك`,
                {
                    type: 'nurse_assigned',
                    orderId: order._id.toString(),
                    nurseName: nurse?.name || 'Nurse'
                }
            );
            console.log('FCM: Nurse assigned notification sent to patient');
        } catch (fcmError) {
            console.error('FCM nurse assigned error:', fcmError);
        }

        res.json({
            success: true,
            message: 'Order accepted successfully',
            data: {
                order: updatedOrder
            }
        });
    } catch (error) {
        console.error('Accept order error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Update order status (nurse workflow actions)
router.post('/order/:orderId/update-status', auth.verifyToken, isNurse, async (req, res) => {
    try {
        const { orderId } = req.params;
        const nurseId = req.user.id;
        const { status, notes } = req.body;

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Verify nurse is assigned to this order
        if (!order.nurseId || order.nurseId.toString() !== nurseId.toString()) {
            return res.status(403).json({
                success: false,
                message: 'You are not assigned to this order'
            });
        }

        // Validate status transition based on nurse workflow
        // Nurse flow: nurse_assigned -> sample_collected (via QR scan)
        // Lab handles: sample_collected -> at_lab -> completed
        const validTransitions = {
            'nurse_assigned': ['sample_collected']
        };

        const currentStatus = order.status;
        if (!validTransitions[currentStatus]?.includes(status)) {
            return res.status(400).json({
                success: false,
                message: `Invalid status transition from ${currentStatus} to ${status}`
            });
        }

        // Update status using appropriate method
        if (status === 'sample_collected') {
            await order.scanQRCode(nurseId);
        }

        // Return updated order
        const updatedOrder = await Order.findById(orderId)
            .populate('patientId', 'name phone email birthDate')
            .populate('labId', 'name address phone city coordinates')
            .populate('nurseId', 'name phone');

        res.json({
            success: true,
            message: 'Order status updated successfully',
            data: {
                order: updatedOrder
            }
        });
    } catch (error) {
        console.error('Update order status error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Add nurse notes to order
router.post('/order/:orderId/notes', auth.verifyToken, isNurse, async (req, res) => {
    try {
        const { orderId } = req.params;
        const nurseId = req.user.id;
        const { notes } = req.body;

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Verify nurse is assigned to this order
        if (!order.nurseId || order.nurseId.toString() !== nurseId.toString()) {
            return res.status(403).json({
                success: false,
                message: 'You are not assigned to this order'
            });
        }

        order.notes.nurseNotes = notes;
        await order.save();

        res.json({
            success: true,
            message: 'Notes added successfully',
            data: {
                order: order
            }
        });
    } catch (error) {
        console.error('Add nurse notes error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Scan patient's QR code to confirm sample collection
router.post('/order/:orderId/scan-qr', auth.verifyToken, isNurse, async (req, res) => {
    try {
        const { orderId } = req.params;
        const nurseId = req.user.id;
        const { qrCode } = req.body;

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Verify nurse is assigned to this order
        if (!order.nurseId || order.nurseId.toString() !== nurseId.toString()) {
            return res.status(403).json({
                success: false,
                message: 'You are not assigned to this order'
            });
        }

        // Verify order is in nurse_assigned status
        if (order.status !== 'nurse_assigned') {
            return res.status(400).json({
                success: false,
                message: 'Order status does not allow QR scanning'
            });
        }

        // Verify the QR code matches
        if (order.qrCode !== qrCode) {
            return res.status(400).json({
                success: false,
                message: 'Invalid QR code'
            });
        }

        // Calculate financials if not already done
        if (!order.financials || !order.financials.commissionRate) {
            await order.calculateFinancials();
        }

        // Update order status using scanQRCode method
        await order.scanQRCode(nurseId);

        // Mark payment as collected (patient pays nurse at this point)
        await order.markPaymentCollected(nurseId);

        // Update nurse balance - add admin's share (what nurse owes admin)
        const nurse = await User.findById(nurseId);
        if (nurse) {
            // Admin's amount is what the nurse owes to admin
            const adminAmount = order.financials?.adminAmount || 0;
            const nurseNetEarning = order.financials?.nurseNetEarning || 0;

            // Nurse balance = what nurse owes to admin (accumulated)
            nurse.nurseBalance = (nurse.nurseBalance || 0) + adminAmount;
            // Total earnings = nurse's net profit after paying both lab and admin
            nurse.totalEarnings = (nurse.totalEarnings || 0) + nurseNetEarning;
            await nurse.save();

            // Create transaction record for the order
            if (adminAmount > 0) {
                const transaction = new Transaction({
                    type: 'commission_earned',
                    amount: adminAmount,
                    orderId: order._id,
                    labId: order.labId,
                    nurseId: nurseId,
                    patientId: order.patientId,
                    description: `Admin share from order ${order.qrCode}`,
                    referenceNumber: Transaction.generateReferenceNumber('commission_earned'),
                    breakdown: {
                        totalAmount: order.pricing.total,
                        labAmount: order.financials?.labAmount || 0,
                        nurseEarningBeforeAdmin: order.financials?.nurseEarningBeforeAdmin || 0,
                        adminAmount: adminAmount,
                        nurseNetEarning: nurseNetEarning,
                        labCommissionRate: order.financials?.labCommissionRate || 0,
                        nurseCommissionRate: order.financials?.nurseCommissionRate || 0,
                    },
                    balanceAfter: {
                        nurseBalance: nurse.nurseBalance,
                    },
                });
                await transaction.save();
            }
        }

        // Return updated order with populated fields
        const updatedOrder = await Order.findById(orderId)
            .populate('patientId', 'name phone email birthDate')
            .populate('labId', 'name address phone city commissionRate coordinates')
            .populate('nurseId', 'name phone nurseCommissionRate');

        res.json({
            success: true,
            message: 'Sample collected successfully',
            data: {
                order: updatedOrder,
                financials: {
                    totalCollected: order.pricing.total,
                    labAmount: order.financials?.labAmount || 0,
                    nurseEarningBeforeAdmin: order.financials?.nurseEarningBeforeAdmin || 0,
                    adminAmount: order.financials?.adminAmount || 0,
                    nurseNetEarning: order.financials?.nurseNetEarning || 0,
                    labCommissionRate: order.financials?.labCommissionRate || 0,
                    nurseCommissionRate: order.financials?.nurseCommissionRate || 0,
                }
            }
        });
    } catch (error) {
        console.error('Scan QR code error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Cancel order (nurse releases the order back to available)
router.post('/order/:orderId/cancel', auth.verifyToken, isNurse, async (req, res) => {
    try {
        const { orderId } = req.params;
        const nurseId = req.user.id;
        const { reason } = req.body;

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Verify nurse is assigned to this order
        if (!order.nurseId || order.nurseId.toString() !== nurseId.toString()) {
            return res.status(403).json({
                success: false,
                message: 'You are not assigned to this order'
            });
        }

        // Can only cancel nurse_assigned orders (before QR scan/sample collection)
        if (order.status !== 'nurse_assigned') {
            return res.status(400).json({
                success: false,
                message: 'Order cannot be cancelled at this stage. Only orders in "nurse_assigned" status can be cancelled.'
            });
        }

        // Store the nurse cancellation info
        if (!order.nurseCancellations) {
            order.nurseCancellations = [];
        }
        order.nurseCancellations.push({
            nurseId: nurseId,
            reason: reason ? reason.trim() : 'No reason provided',
            cancelledAt: new Date()
        });

        // Clear nurse assignment
        order.nurseId = null;
        order.nurseAssignment = {
            assignedAt: null,
            acceptedAt: null,
            estimatedArrival: null,
            notes: null
        };

        // Revert status to confirmed (waiting for new nurse)
        order.status = 'confirmed';
        order.statusHistory.push({
            status: 'confirmed',
            timestamp: new Date(),
            updatedBy: nurseId,
            notes: reason ? `Order released by nurse. Reason: ${reason.trim()}` : 'Order released by nurse'
        });

        await order.save();

        res.json({
            success: true,
            message: 'Order cancelled successfully. It is now available for other nurses.',
            data: {
                order: order
            }
        });
    } catch (error) {
        console.error('Nurse cancel order error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

module.exports = router;
