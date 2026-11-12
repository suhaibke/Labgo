const express = require('express');
const router = express.Router();
const NurseApplication = require('../../models/NurseApplication');
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
// NURSE APPLICATIONS MANAGEMENT
// ============================================================================

// Get all nurse applications with filters
router.get('/applications', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { status, city, page = 1, limit = 20, startDate, endDate } = req.query;

        const query = {};
        if (status) query.status = status;
        if (city) query['location.city'] = new RegExp(city, 'i');
        if (startDate || endDate) {
            query.submittedAt = {};
            if (startDate) query.submittedAt.$gte = new Date(startDate);
            if (endDate) query.submittedAt.$lte = new Date(endDate);
        }

        const applications = await NurseApplication.find(query)
            .populate('userId', 'name email phone')
            .populate('reviewDetails.reviewedBy', 'name email')
            .populate('nurseUserId', 'name email phone')
            .sort({ submittedAt: -1 })
            .limit(parseInt(limit))
            .skip((parseInt(page) - 1) * parseInt(limit));

        const total = await NurseApplication.countDocuments(query);

        // Get statistics
        const stats = await NurseApplication.aggregate([
            {
                $group: {
                    _id: null,
                    total: { $sum: 1 },
                    pending: { $sum: { $cond: [{ $eq: ['$status', 'pending'] }, 1, 0] } },
                    underReview: { $sum: { $cond: [{ $eq: ['$status', 'under_review'] }, 1, 0] } },
                    approved: { $sum: { $cond: [{ $eq: ['$status', 'approved'] }, 1, 0] } },
                    rejected: { $sum: { $cond: [{ $eq: ['$status', 'rejected'] }, 1, 0] } },
                    onHold: { $sum: { $cond: [{ $eq: ['$status', 'on_hold'] }, 1, 0] } }
                }
            }
        ]);

        res.json({
            success: true,
            data: {
                applications: applications,
                total: total,
                page: parseInt(page),
                pages: Math.ceil(total / parseInt(limit)),
                stats: stats[0] || { total: 0, pending: 0, underReview: 0, approved: 0, rejected: 0, onHold: 0 }
            }
        });
    } catch (error) {
        console.error('Get nurse applications error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get single application details
router.get('/applications/:applicationId', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { applicationId } = req.params;

        const application = await NurseApplication.findById(applicationId)
            .populate('userId', 'name email phone birthDate gender')
            .populate('reviewDetails.reviewedBy', 'name email')
            .populate('nurseUserId', 'name email phone');

        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        res.json({
            success: true,
            data: {
                application
            }
        });
    } catch (error) {
        console.error('Get application error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Mark application as under review
router.post('/applications/:applicationId/review', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { applicationId } = req.params;
        const adminId = req.user.id;

        const application = await NurseApplication.findById(applicationId);

        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        if (application.status !== 'pending') {
            return res.status(400).json({
                success: false,
                message: 'Only pending applications can be marked as under review'
            });
        }

        await application.markAsUnderReview(adminId);

        res.json({
            success: true,
            message: 'Application marked as under review',
            data: {
                application
            }
        });
    } catch (error) {
        console.error('Mark under review error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Approve application and create nurse user account
router.post('/applications/:applicationId/approve', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { applicationId } = req.params;
        const { notes, commissionRate } = req.body;
        const adminId = req.user.id;

        // Validate commission rate
        if (commissionRate === undefined || commissionRate === null) {
            return res.status(400).json({
                success: false,
                message: 'Commission rate is required'
            });
        }

        const parsedCommissionRate = parseFloat(commissionRate);
        if (isNaN(parsedCommissionRate) || parsedCommissionRate < 0 || parsedCommissionRate > 100) {
            return res.status(400).json({
                success: false,
                message: 'Commission rate must be between 0 and 100'
            });
        }

        const application = await NurseApplication.findById(applicationId).populate('userId');

        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        if (!['pending', 'under_review'].includes(application.status)) {
            return res.status(400).json({
                success: false,
                message: 'Application cannot be approved at this stage'
            });
        }

        // Create nurse user account
        const nurseUser = await User.findById(application.userId._id);

        if (!nurseUser) {
            return res.status(404).json({
                success: false,
                message: 'Original user not found'
            });
        }

        // Update user role to nurse and set commission rate
        nurseUser.role = 'nurse';
        nurseUser.nurseCommissionRate = parsedCommissionRate;
        await nurseUser.save();

        // Approve application
        await application.approve(adminId, nurseUser._id, notes);

        res.json({
            success: true,
            message: 'Application approved successfully. Nurse account created.',
            data: {
                application,
                nurseUser: {
                    id: nurseUser._id,
                    name: nurseUser.name,
                    email: nurseUser.email,
                    phone: nurseUser.phone,
                    commissionRate: nurseUser.nurseCommissionRate
                }
            }
        });
    } catch (error) {
        console.error('Approve application error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Reject application
router.post('/applications/:applicationId/reject', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { applicationId } = req.params;
        const { reason } = req.body;
        const adminId = req.user.id;

        if (!reason) {
            return res.status(400).json({
                success: false,
                message: 'Rejection reason is required'
            });
        }

        const application = await NurseApplication.findById(applicationId);

        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        if (!['pending', 'under_review'].includes(application.status)) {
            return res.status(400).json({
                success: false,
                message: 'Application cannot be rejected at this stage'
            });
        }

        await application.reject(adminId, reason);

        res.json({
            success: true,
            message: 'Application rejected successfully',
            data: {
                application
            }
        });
    } catch (error) {
        console.error('Reject application error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Put application on hold
router.post('/applications/:applicationId/hold', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { applicationId } = req.params;
        const { notes } = req.body;
        const adminId = req.user.id;

        const application = await NurseApplication.findById(applicationId);

        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        application.status = 'on_hold';
        application.reviewDetails = {
            reviewedBy: adminId,
            reviewedAt: new Date(),
            notes: notes
        };
        await application.save();

        res.json({
            success: true,
            message: 'Application put on hold',
            data: {
                application
            }
        });
    } catch (error) {
        console.error('Hold application error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Remove application from hold (return to pending)
router.post('/applications/:applicationId/remove-hold', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { applicationId } = req.params;
        const adminId = req.user.id;

        const application = await NurseApplication.findById(applicationId);

        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        if (application.status !== 'on_hold') {
            return res.status(400).json({
                success: false,
                message: 'Application is not on hold'
            });
        }

        application.status = 'pending';
        application.reviewDetails = {
            reviewedBy: adminId,
            reviewedAt: new Date(),
            notes: 'Removed from hold, returned to pending'
        };
        await application.save();

        res.json({
            success: true,
            message: 'Application removed from hold',
            data: {
                application
            }
        });
    } catch (error) {
        console.error('Remove hold error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// ============================================================================
// ACTIVE NURSES MANAGEMENT
// ============================================================================

// Get all active nurses
router.get('/active', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { city, status, page = 1, limit = 20 } = req.query;

        // Find users with nurse role
        const query = { role: 'nurse' };

        const nurses = await User.find(query)
            .select('name email phone gender birthDate createdAt defaultLocation averageRating totalRatings nurseCommissionRate')
            .sort({ createdAt: -1 })
            .limit(parseInt(limit))
            .skip((parseInt(page) - 1) * parseInt(limit));

        const total = await User.countDocuments(query);

        // Get nurse statistics
        const stats = {
            total: total,
            active: await User.countDocuments({ role: 'nurse' }),
            withActiveOrders: await Order.countDocuments({ nurseId: { $exists: true, $ne: null }, status: { $in: ['nurse_assigned', 'at_patient', 'going_to_lab'] } })
        };

        res.json({
            success: true,
            data: {
                nurses: nurses,
                total: total,
                page: parseInt(page),
                pages: Math.ceil(total / parseInt(limit)),
                stats
            }
        });
    } catch (error) {
        console.error('Get nurses error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get nurse details with their applications and orders
router.get('/active/:nurseId', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { nurseId } = req.params;

        const nurse = await User.findById(nurseId).select('-password');

        if (!nurse || nurse.role !== 'nurse') {
            return res.status(404).json({
                success: false,
                message: 'Nurse not found'
            });
        }

        // Get nurse's application history
        const applications = await NurseApplication.find({ userId: nurseId })
            .populate('reviewDetails.reviewedBy', 'name email')
            .sort({ submittedAt: -1 });

        // Get nurse's active/recent orders
        const orders = await Order.find({ nurseId })
            .populate('patientId', 'name phone')
            .populate('labId', 'name')
            .sort({ createdAt: -1 })
            .limit(10);

        res.json({
            success: true,
            data: {
                nurse,
                applications,
                orders
            }
        });
    } catch (error) {
        console.error('Get nurse details error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Update nurse status (activate/deactivate)
router.patch('/active/:nurseId/status', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { nurseId } = req.params;
        const { isActive } = req.body;

        const nurse = await User.findById(nurseId);

        if (!nurse || nurse.role !== 'nurse') {
            return res.status(404).json({
                success: false,
                message: 'Nurse not found'
            });
        }

        // You could add an isActive field to User schema, for now we'll use a different approach
        // This is a placeholder for future functionality

        res.json({
            success: true,
            message: 'Nurse status updated successfully',
            data: {
                nurse
            }
        });
    } catch (error) {
        console.error('Update nurse status error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Update nurse commission rate
router.patch('/active/:nurseId/commission', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { nurseId } = req.params;
        const { commissionRate } = req.body;

        // Validate commission rate
        if (commissionRate === undefined || commissionRate === null) {
            return res.status(400).json({
                success: false,
                message: 'Commission rate is required'
            });
        }

        const parsedCommissionRate = parseFloat(commissionRate);
        if (isNaN(parsedCommissionRate) || parsedCommissionRate < 0 || parsedCommissionRate > 100) {
            return res.status(400).json({
                success: false,
                message: 'Commission rate must be between 0 and 100'
            });
        }

        const nurse = await User.findById(nurseId);

        if (!nurse || nurse.role !== 'nurse') {
            return res.status(404).json({
                success: false,
                message: 'Nurse not found'
            });
        }

        nurse.nurseCommissionRate = parsedCommissionRate;
        await nurse.save();

        res.json({
            success: true,
            message: 'Nurse commission rate updated successfully',
            data: {
                nurse: {
                    id: nurse._id,
                    name: nurse.name,
                    commissionRate: nurse.nurseCommissionRate
                }
            }
        });
    } catch (error) {
        console.error('Update nurse commission error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Update nurse description
router.patch('/active/:nurseId/description', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { nurseId } = req.params;
        const { description } = req.body;

        const nurse = await User.findById(nurseId);

        if (!nurse || nurse.role !== 'nurse') {
            return res.status(404).json({
                success: false,
                message: 'Nurse not found'
            });
        }

        nurse.nurseDescription = description?.trim() || null;
        await nurse.save();

        res.json({
            success: true,
            message: 'Nurse description updated successfully',
            data: {
                nurse: {
                    id: nurse._id,
                    name: nurse.name,
                    description: nurse.nurseDescription
                }
            }
        });
    } catch (error) {
        console.error('Update nurse description error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get all blocked nurses
router.get('/blocked', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { page = 1, limit = 20, search } = req.query;

        // Build query for blocked nurses
        const query = { role: 'nurse', status: 'blocked' };

        // Add search filter if provided
        if (search) {
            query.$or = [
                { name: new RegExp(search, 'i') },
                { email: new RegExp(search, 'i') },
                { phone: new RegExp(search, 'i') }
            ];
        }

        const blockedNurses = await User.find(query)
            .select('name email phone gender birthDate createdAt blockedAt blockedBy blockReason')
            .populate('blockedBy', 'name email')
            .sort({ blockedAt: -1 })
            .limit(parseInt(limit))
            .skip((parseInt(page) - 1) * parseInt(limit));

        const total = await User.countDocuments(query);

        res.json({
            success: true,
            data: {
                nurses: blockedNurses,
                total: total,
                page: parseInt(page),
                pages: Math.ceil(total / parseInt(limit))
            }
        });
    } catch (error) {
        console.error('Get blocked nurses error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// ============================================================================
// STATISTICS
// ============================================================================

// Get nurse management statistics
router.get('/stats/overview', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { startDate, endDate } = req.query;

        const matchQuery = {};
        if (startDate || endDate) {
            matchQuery.submittedAt = {};
            if (startDate) matchQuery.submittedAt.$gte = new Date(startDate);
            if (endDate) matchQuery.submittedAt.$lte = new Date(endDate);
        }

        const applicationStats = await NurseApplication.aggregate([
            { $match: matchQuery },
            {
                $group: {
                    _id: null,
                    totalApplications: { $sum: 1 },
                    pending: { $sum: { $cond: [{ $eq: ['$status', 'pending'] }, 1, 0] } },
                    underReview: { $sum: { $cond: [{ $eq: ['$status', 'under_review'] }, 1, 0] } },
                    approved: { $sum: { $cond: [{ $eq: ['$status', 'approved'] }, 1, 0] } },
                    rejected: { $sum: { $cond: [{ $eq: ['$status', 'rejected'] }, 1, 0] } },
                    onHold: { $sum: { $cond: [{ $eq: ['$status', 'on_hold'] }, 1, 0] } }
                }
            }
        ]);

        const totalNurses = await User.countDocuments({ role: 'nurse' });

        const applicationsByCity = await NurseApplication.aggregate([
            { $match: matchQuery },
            {
                $group: {
                    _id: '$location.city',
                    count: { $sum: 1 }
                }
            },
            { $sort: { count: -1 } },
            { $limit: 10 }
        ]);

        res.json({
            success: true,
            data: {
                stats: applicationStats[0] || {
                    totalApplications: 0,
                    pending: 0,
                    underReview: 0,
                    approved: 0,
                    rejected: 0,
                    onHold: 0
                },
                totalNurses,
                applicationsByCity
            }
        });
    } catch (error) {
        console.error('Get nurse stats error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});


// Get individual nurse analytics
router.get('/active/:nurseId/analytics', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const mongoose = require('mongoose');
        const { nurseId } = req.params;
        const { startDate, endDate, page = 1, limit = 20 } = req.query;

        // Convert nurseId to ObjectId for aggregation
        const nurseObjectId = new mongoose.Types.ObjectId(nurseId);

        // Verify nurse exists
        const nurse = await User.findById(nurseId);
        if (!nurse || nurse.role !== 'nurse') {
            return res.status(404).json({
                success: false,
                message: 'Nurse not found'
            });
        }

        // Build date filter
        const dateFilter = {};
        if (startDate) {
            dateFilter.$gte = new Date(startDate);
        }
        if (endDate) {
            const end = new Date(endDate);
            end.setHours(23, 59, 59, 999);
            dateFilter.$lte = end;
        }

        // Build query for orders - use ObjectId for aggregation
        const orderQuery = { nurseId: nurseObjectId };
        if (Object.keys(dateFilter).length > 0) {
            orderQuery.createdAt = dateFilter;
        }

        // Get order statistics
        const orderStats = await Order.aggregate([
            { $match: orderQuery },

            {
                $group: {
                    _id: null,
                    totalOrders: { $sum: 1 },
                    completedOrders: { $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] } },
                    cancelledOrders: { $sum: { $cond: [{ $eq: ['$status', 'cancelled'] }, 1, 0] } },
                    pendingOrders: { $sum: { $cond: [{ $in: ['$status', ['pending', 'confirmed', 'nurse_assigned']] }, 1, 0] } },
                    inProgressOrders: { $sum: { $cond: [{ $in: ['$status', ['sample_collected', 'at_lab']] }, 1, 0] } },
                    totalEarnings: { $sum: '$financials.nurseNetEarning' },
                    totalRevenue: { $sum: '$pricing.total' },
                    avgOrderValue: { $avg: '$pricing.total' }
                }
            }
        ]);

        // Get orders by status breakdown
        const ordersByStatus = await Order.aggregate([
            { $match: orderQuery },
            {
                $group: {
                    _id: '$status',
                    count: { $sum: 1 }
                }
            },
            { $sort: { count: -1 } }
        ]);

        // Get daily orders trend for charts
        const ordersTrend = await Order.aggregate([
            { $match: orderQuery },
            {
                $group: {
                    _id: {
                        $dateToString: { format: '%Y-%m-%d', date: '$createdAt' }
                    },
                    count: { $sum: 1 },
                    earnings: { $sum: '$financials.nurseNetEarning' }
                }
            },
            { $sort: { _id: 1 } }
        ]);

        // Get paginated orders list
        const orders = await Order.find(orderQuery)
            .populate('patientId', 'name phone')
            .populate('labId', 'name')
            .sort({ createdAt: -1 })
            .limit(parseInt(limit))
            .skip((parseInt(page) - 1) * parseInt(limit));

        const totalOrders = await Order.countDocuments(orderQuery);

        // Get rating statistics
        const ratingStats = await Order.aggregate([
            { $match: { ...orderQuery, 'rating.nurseRating': { $exists: true } } },
            {
                $group: {
                    _id: null,
                    avgRating: { $avg: '$rating.nurseRating' },
                    totalRatings: { $sum: 1 }
                }
            }
        ]);

        const stats = orderStats[0] || {
            totalOrders: 0,
            completedOrders: 0,
            cancelledOrders: 0,
            pendingOrders: 0,
            inProgressOrders: 0,
            totalEarnings: 0,
            totalRevenue: 0,
            avgOrderValue: 0
        };

        const ratings = ratingStats[0] || { avgRating: 0, totalRatings: 0 };

        res.json({
            success: true,
            data: {
                summary: {
                    ...stats,
                    avgRating: ratings.avgRating || 0,
                    totalRatings: ratings.totalRatings || 0,
                    completionRate: stats.totalOrders > 0
                        ? Math.round((stats.completedOrders / stats.totalOrders) * 100)
                        : 0
                },
                ordersByStatus: ordersByStatus.map(item => ({
                    status: item._id,
                    count: item.count
                })),
                ordersTrend: ordersTrend.map(item => ({
                    date: item._id,
                    count: item.count,
                    earnings: item.earnings || 0
                })),
                orders,
                pagination: {
                    total: totalOrders,
                    page: parseInt(page),
                    pages: Math.ceil(totalOrders / parseInt(limit)),
                    limit: parseInt(limit)
                }
            }
        });
    } catch (error) {
        console.error('Get nurse analytics error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// ============================================================================
// NURSE BLOCKING MANAGEMENT
// ============================================================================

// Block a nurse
router.patch('/active/:nurseId/block', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { nurseId } = req.params;
        const { reason } = req.body;
        const adminId = req.user.id;

        if (!reason || reason.trim().length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Block reason is required'
            });
        }

        const nurse = await User.findById(nurseId);

        if (!nurse || nurse.role !== 'nurse') {
            return res.status(404).json({
                success: false,
                message: 'Nurse not found'
            });
        }

        if (nurse.status === 'blocked') {
            return res.status(400).json({
                success: false,
                message: 'Nurse is already blocked'
            });
        }

        nurse.status = 'blocked';
        nurse.blockedAt = new Date();
        nurse.blockedBy = adminId;
        nurse.blockReason = reason.trim();

        await nurse.save();

        res.json({
            success: true,
            message: 'Nurse blocked successfully',
            data: {
                nurse: {
                    id: nurse._id,
                    name: nurse.name,
                    status: nurse.status,
                    blockedAt: nurse.blockedAt,
                    blockReason: nurse.blockReason
                }
            }
        });
    } catch (error) {
        console.error('Block nurse error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Unblock a nurse
router.patch('/active/:nurseId/unblock', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { nurseId } = req.params;

        const nurse = await User.findById(nurseId);

        if (!nurse || nurse.role !== 'nurse') {
            return res.status(404).json({
                success: false,
                message: 'Nurse not found'
            });
        }

        if (nurse.status !== 'blocked') {
            return res.status(400).json({
                success: false,
                message: 'Nurse is not blocked'
            });
        }

        nurse.status = 'active';
        nurse.blockedAt = null;
        nurse.blockedBy = null;
        nurse.blockReason = null;

        await nurse.save();

        res.json({
            success: true,
            message: 'Nurse unblocked successfully',
            data: {
                nurse: {
                    id: nurse._id,
                    name: nurse.name,
                    status: nurse.status
                }
            }
        });
    } catch (error) {
        console.error('Unblock nurse error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

module.exports = router;
