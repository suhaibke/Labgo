const express = require('express');
const router = express.Router();
const User = require('../../models/User');
const Order = require('../../models/Order');
const auth = require('../../middleware/auth');

// Admin middleware
const requireAdmin = async (req, res, next) => {
    if (req.user.role !== 'admin') {
        return res.status(403).json({
            success: false,
            message: 'Access denied. Admin role required.'
        });
    }
    next();
};

// ============================================================================
// PATIENTS MANAGEMENT
// ============================================================================

// Get all patients with pagination and search
router.get('/', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { page = 1, limit = 12, search, status } = req.query;

        const query = { role: 'patient' };

        // Status filter
        if (status && status !== 'all') {
            query.status = status;
        }

        // Search filter
        if (search) {
            query.$or = [
                { name: { $regex: search, $options: 'i' } },
                { email: { $regex: search, $options: 'i' } },
                { phone: { $regex: search, $options: 'i' } }
            ];
        }

        const patients = await User.find(query)
            .select('name email phone gender birthDate createdAt status blockedAt blockedBy blockReason')
            .populate('blockedBy', 'name email')
            .sort({ createdAt: -1 })
            .limit(parseInt(limit))
            .skip((parseInt(page) - 1) * parseInt(limit));

        const total = await User.countDocuments(query);

        // Get statistics
        const stats = {
            total: await User.countDocuments({ role: 'patient' }),
            active: await User.countDocuments({ role: 'patient', status: 'active' }),
            blocked: await User.countDocuments({ role: 'patient', status: 'blocked' }),
            suspended: await User.countDocuments({ role: 'patient', status: 'suspended' })
        };

        res.json({
            success: true,
            data: {
                patients,
                total,
                page: parseInt(page),
                pages: Math.ceil(total / parseInt(limit)),
                stats
            }
        });
    } catch (error) {
        console.error('Get patients error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get patient details with order history
router.get('/:patientId', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { patientId } = req.params;

        const patient = await User.findById(patientId)
            .select('-password')
            .populate('blockedBy', 'name email');

        if (!patient || patient.role !== 'patient') {
            return res.status(404).json({
                success: false,
                message: 'Patient not found'
            });
        }

        // Get patient orders
        const orders = await Order.find({ patientId })
            .populate('labId', 'name')
            .populate('nurseId', 'name')
            .sort({ createdAt: -1 })
            .limit(10);

        // Calculate order statistics
        const orderStats = await Order.aggregate([
            { $match: { patientId: patient._id } },
            {
                $group: {
                    _id: null,
                    totalOrders: { $sum: 1 },
                    completedOrders: { $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] } },
                    cancelledOrders: { $sum: { $cond: [{ $eq: ['$status', 'cancelled'] }, 1, 0] } },
                    totalSpent: { $sum: '$pricing.total' }
                }
            }
        ]);

        res.json({
            success: true,
            data: {
                patient,
                orders,
                stats: orderStats[0] || {
                    totalOrders: 0,
                    completedOrders: 0,
                    cancelledOrders: 0,
                    totalSpent: 0
                }
            }
        });
    } catch (error) {
        console.error('Get patient details error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Block a patient
router.patch('/:patientId/block', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { patientId } = req.params;
        const { reason } = req.body;
        const adminId = req.user.id;

        if (!reason || reason.trim().length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Block reason is required'
            });
        }

        const patient = await User.findById(patientId);

        if (!patient || patient.role !== 'patient') {
            return res.status(404).json({
                success: false,
                message: 'Patient not found'
            });
        }

        if (patient.status === 'blocked') {
            return res.status(400).json({
                success: false,
                message: 'Patient is already blocked'
            });
        }

        patient.status = 'blocked';
        patient.blockedAt = new Date();
        patient.blockedBy = adminId;
        patient.blockReason = reason.trim();

        await patient.save();

        res.json({
            success: true,
            message: 'Patient blocked successfully',
            data: {
                patient: {
                    id: patient._id,
                    name: patient.name,
                    status: patient.status,
                    blockedAt: patient.blockedAt,
                    blockReason: patient.blockReason
                }
            }
        });
    } catch (error) {
        console.error('Block patient error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Unblock a patient
router.patch('/:patientId/unblock', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { patientId } = req.params;

        const patient = await User.findById(patientId);

        if (!patient || patient.role !== 'patient') {
            return res.status(404).json({
                success: false,
                message: 'Patient not found'
            });
        }

        if (patient.status !== 'blocked') {
            return res.status(400).json({
                success: false,
                message: 'Patient is not blocked'
            });
        }

        patient.status = 'active';
        patient.blockedAt = null;
        patient.blockedBy = null;
        patient.blockReason = null;

        await patient.save();

        res.json({
            success: true,
            message: 'Patient unblocked successfully',
            data: {
                patient: {
                    id: patient._id,
                    name: patient.name,
                    status: patient.status
                }
            }
        });
    } catch (error) {
        console.error('Unblock patient error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// ============================================================================
// STATISTICS
// ============================================================================

// Get patient statistics
router.get('/stats/overview', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { startDate, endDate } = req.query;

        const dateQuery = {};
        if (startDate || endDate) {
            dateQuery.createdAt = {};
            if (startDate) dateQuery.createdAt.$gte = new Date(startDate);
            if (endDate) dateQuery.createdAt.$lte = new Date(endDate);
        }

        const stats = await User.aggregate([
            { $match: { ...dateQuery, role: 'patient' } },
            {
                $group: {
                    _id: null,
                    total: { $sum: 1 },
                    active: { $sum: { $cond: [{ $eq: ['$status', 'active'] }, 1, 0] } },
                    blocked: { $sum: { $cond: [{ $eq: ['$status', 'blocked'] }, 1, 0] } },
                    suspended: { $sum: { $cond: [{ $eq: ['$status', 'suspended'] }, 1, 0] } }
                }
            }
        ]);

        // New registrations trend
        const registrationsTrend = await User.aggregate([
            { $match: { ...dateQuery, role: 'patient' } },
            {
                $group: {
                    _id: {
                        $dateToString: { format: '%Y-%m-%d', date: '$createdAt' }
                    },
                    count: { $sum: 1 }
                }
            },
            { $sort: { _id: 1 } },
            { $limit: 30 }
        ]);

        res.json({
            success: true,
            data: {
                stats: stats[0] || {
                    total: 0,
                    active: 0,
                    blocked: 0,
                    suspended: 0
                },
                registrationsTrend
            }
        });
    } catch (error) {
        console.error('Get patient stats error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

module.exports = router;
