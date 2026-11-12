const express = require('express');
const router = express.Router();
const Order = require('../../models/Order');
const { verifyToken } = require('../../middleware/auth');

// Apply admin middleware to all routes
router.use(verifyToken);

// Get bad ratings report (ratings <= 3)
router.get('/bad-ratings', async (req, res) => {
    try {
        const { type, page = 1, limit = 20, startDate, endDate } = req.query;

        // Build query for orders with low ratings
        const query = {
            'rating.ratedAt': { $exists: true },
            $or: [
                { 'rating.labRating': { $lte: 3 } },
                { 'rating.nurseRating': { $lte: 3 } }
            ]
        };

        // Filter by type
        if (type === 'lab') {
            query['rating.labRating'] = { $lte: 3 };
            delete query.$or;
        } else if (type === 'nurse') {
            query['rating.nurseRating'] = { $lte: 3 };
            delete query.$or;
        }

        // Date filters
        if (startDate || endDate) {
            query['rating.ratedAt'] = {};
            if (startDate) {
                query['rating.ratedAt'].$gte = new Date(startDate);
            }
            if (endDate) {
                const end = new Date(endDate);
                end.setHours(23, 59, 59, 999);
                query['rating.ratedAt'].$lte = end;
            }
        }

        const skip = (parseInt(page) - 1) * parseInt(limit);

        const orders = await Order.find(query)
            .populate('patientId', 'name email phone')
            .populate('labId', 'name address city phone')
            .populate('nurseId', 'name email phone')
            .sort({ 'rating.ratedAt': -1 })
            .skip(skip)
            .limit(parseInt(limit));

        const total = await Order.countDocuments(query);

        // Format the response
        const badRatings = orders.map(order => {
            const ratings = [];

            if (order.rating.labRating && order.rating.labRating <= 3) {
                ratings.push({
                    type: 'lab',
                    orderId: order._id,
                    qrCode: order.qrCode,
                    rating: order.rating.labRating,
                    reason: order.rating.labRatingReason || 'No reason provided',
                    ratedAt: order.rating.ratedAt,
                    target: order.labId ? {
                        id: order.labId._id,
                        name: order.labId.name,
                        city: order.labId.city
                    } : null,
                    patient: order.patientId ? {
                        id: order.patientId._id,
                        name: order.patientId.name,
                        phone: order.patientId.phone
                    } : null
                });
            }

            if (order.rating.nurseRating && order.rating.nurseRating <= 3) {
                ratings.push({
                    type: 'nurse',
                    orderId: order._id,
                    qrCode: order.qrCode,
                    rating: order.rating.nurseRating,
                    reason: order.rating.nurseRatingReason || 'No reason provided',
                    ratedAt: order.rating.ratedAt,
                    target: order.nurseId ? {
                        id: order.nurseId._id,
                        name: order.nurseId.name,
                        phone: order.nurseId.phone
                    } : null,
                    patient: order.patientId ? {
                        id: order.patientId._id,
                        name: order.patientId.name,
                        phone: order.patientId.phone
                    } : null
                });
            }

            return ratings;
        }).flat();

        // Count stats
        const labBadRatingsCount = await Order.countDocuments({
            'rating.ratedAt': { $exists: true },
            'rating.labRating': { $lte: 3 }
        });

        const nurseBadRatingsCount = await Order.countDocuments({
            'rating.ratedAt': { $exists: true },
            'rating.nurseRating': { $lte: 3 }
        });

        res.json({
            success: true,
            data: {
                badRatings: badRatings,
                stats: {
                    totalLabBadRatings: labBadRatingsCount,
                    totalNurseBadRatings: nurseBadRatingsCount,
                    total: labBadRatingsCount + nurseBadRatingsCount
                },
                pagination: {
                    page: parseInt(page),
                    limit: parseInt(limit),
                    total: total,
                    pages: Math.ceil(total / parseInt(limit))
                }
            }
        });
    } catch (error) {
        console.error('Get bad ratings error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get overall ratings summary
router.get('/ratings-summary', async (req, res) => {
    try {
        const { startDate, endDate } = req.query;

        const matchQuery = {
            'rating.ratedAt': { $exists: true }
        };

        if (startDate || endDate) {
            matchQuery['rating.ratedAt'] = {};
            if (startDate) {
                matchQuery['rating.ratedAt'].$gte = new Date(startDate);
            }
            if (endDate) {
                const end = new Date(endDate);
                end.setHours(23, 59, 59, 999);
                matchQuery['rating.ratedAt'].$lte = end;
            }
        }

        const summary = await Order.aggregate([
            { $match: matchQuery },
            {
                $group: {
                    _id: null,
                    totalRatings: { $sum: 1 },
                    avgLabRating: { $avg: '$rating.labRating' },
                    avgNurseRating: { $avg: '$rating.nurseRating' },
                    avgServiceRating: { $avg: '$rating.serviceRating' },
                    labRating1: { $sum: { $cond: [{ $eq: ['$rating.labRating', 1] }, 1, 0] } },
                    labRating2: { $sum: { $cond: [{ $eq: ['$rating.labRating', 2] }, 1, 0] } },
                    labRating3: { $sum: { $cond: [{ $eq: ['$rating.labRating', 3] }, 1, 0] } },
                    labRating4: { $sum: { $cond: [{ $eq: ['$rating.labRating', 4] }, 1, 0] } },
                    labRating5: { $sum: { $cond: [{ $eq: ['$rating.labRating', 5] }, 1, 0] } },
                    nurseRating1: { $sum: { $cond: [{ $eq: ['$rating.nurseRating', 1] }, 1, 0] } },
                    nurseRating2: { $sum: { $cond: [{ $eq: ['$rating.nurseRating', 2] }, 1, 0] } },
                    nurseRating3: { $sum: { $cond: [{ $eq: ['$rating.nurseRating', 3] }, 1, 0] } },
                    nurseRating4: { $sum: { $cond: [{ $eq: ['$rating.nurseRating', 4] }, 1, 0] } },
                    nurseRating5: { $sum: { $cond: [{ $eq: ['$rating.nurseRating', 5] }, 1, 0] } }
                }
            }
        ]);

        res.json({
            success: true,
            data: summary[0] || {
                totalRatings: 0,
                avgLabRating: 0,
                avgNurseRating: 0,
                avgServiceRating: 0,
                labRating1: 0,
                labRating2: 0,
                labRating3: 0,
                labRating4: 0,
                labRating5: 0,
                nurseRating1: 0,
                nurseRating2: 0,
                nurseRating3: 0,
                nurseRating4: 0,
                nurseRating5: 0
            }
        });
    } catch (error) {
        console.error('Get ratings summary error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get ALL ratings report (all ratings with notes)
router.get('/all-ratings', async (req, res) => {
    try {
        const { type, minRating, maxRating, page = 1, limit = 20, startDate, endDate } = req.query;

        // Build query for orders with ratings
        const query = {
            'rating.ratedAt': { $exists: true }
        };

        // Filter by rating range
        const ratingFilters = [];
        if (type === 'lab' || !type) {
            const labFilter = { 'rating.labRating': { $exists: true, $ne: null } };
            if (minRating) labFilter['rating.labRating'].$gte = parseInt(minRating);
            if (maxRating) labFilter['rating.labRating'].$lte = parseInt(maxRating);
            if (type === 'lab') {
                Object.assign(query, labFilter);
            } else {
                ratingFilters.push(labFilter);
            }
        }
        if (type === 'nurse' || !type) {
            const nurseFilter = { 'rating.nurseRating': { $exists: true, $ne: null } };
            if (minRating) nurseFilter['rating.nurseRating'].$gte = parseInt(minRating);
            if (maxRating) nurseFilter['rating.nurseRating'].$lte = parseInt(maxRating);
            if (type === 'nurse') {
                Object.assign(query, nurseFilter);
            } else {
                ratingFilters.push(nurseFilter);
            }
        }

        if (!type && ratingFilters.length > 0) {
            query.$or = ratingFilters;
        }

        // Date filters
        if (startDate || endDate) {
            query['rating.ratedAt'] = query['rating.ratedAt'] || {};
            if (startDate) {
                query['rating.ratedAt'].$gte = new Date(startDate);
            }
            if (endDate) {
                const end = new Date(endDate);
                end.setHours(23, 59, 59, 999);
                query['rating.ratedAt'].$lte = end;
            }
        }

        const skip = (parseInt(page) - 1) * parseInt(limit);

        const orders = await Order.find(query)
            .populate('patientId', 'name email phone')
            .populate('labId', 'name address city phone averageRating totalReviews')
            .populate('nurseId', 'name email phone averageRating totalRatings')
            .sort({ 'rating.ratedAt': -1 })
            .skip(skip)
            .limit(parseInt(limit));

        const total = await Order.countDocuments(query);

        // Format the response
        const allRatings = [];
        orders.forEach(order => {
            if (order.rating.labRating && (!type || type === 'lab')) {
                allRatings.push({
                    type: 'lab',
                    orderId: order._id,
                    qrCode: order.qrCode,
                    rating: order.rating.labRating,
                    reason: order.rating.labRatingReason || '',
                    comment: order.rating.comment || '',
                    ratedAt: order.rating.ratedAt,
                    target: order.labId ? {
                        id: order.labId._id,
                        name: order.labId.name,
                        city: order.labId.city,
                        averageRating: order.labId.averageRating,
                        totalReviews: order.labId.totalReviews
                    } : null,
                    patient: order.patientId ? {
                        id: order.patientId._id,
                        name: order.patientId.name,
                        phone: order.patientId.phone
                    } : null
                });
            }

            if (order.rating.nurseRating && (!type || type === 'nurse')) {
                allRatings.push({
                    type: 'nurse',
                    orderId: order._id,
                    qrCode: order.qrCode,
                    rating: order.rating.nurseRating,
                    reason: order.rating.nurseRatingReason || '',
                    comment: order.rating.comment || '',
                    ratedAt: order.rating.ratedAt,
                    target: order.nurseId ? {
                        id: order.nurseId._id,
                        name: order.nurseId.name,
                        phone: order.nurseId.phone,
                        averageRating: order.nurseId.averageRating,
                        totalRatings: order.nurseId.totalRatings
                    } : null,
                    patient: order.patientId ? {
                        id: order.patientId._id,
                        name: order.patientId.name,
                        phone: order.patientId.phone
                    } : null
                });
            }
        });

        // Get stats
        const statsAgg = await Order.aggregate([
            { $match: { 'rating.ratedAt': { $exists: true } } },
            {
                $group: {
                    _id: null,
                    totalLabRatings: { $sum: { $cond: [{ $ifNull: ['$rating.labRating', false] }, 1, 0] } },
                    totalNurseRatings: { $sum: { $cond: [{ $ifNull: ['$rating.nurseRating', false] }, 1, 0] } },
                    avgLabRating: { $avg: '$rating.labRating' },
                    avgNurseRating: { $avg: '$rating.nurseRating' }
                }
            }
        ]);

        const stats = statsAgg[0] || {
            totalLabRatings: 0,
            totalNurseRatings: 0,
            avgLabRating: 0,
            avgNurseRating: 0
        };

        res.json({
            success: true,
            data: {
                ratings: allRatings,
                stats: {
                    totalLabRatings: stats.totalLabRatings,
                    totalNurseRatings: stats.totalNurseRatings,
                    total: stats.totalLabRatings + stats.totalNurseRatings,
                    avgLabRating: stats.avgLabRating ? stats.avgLabRating.toFixed(1) : '0.0',
                    avgNurseRating: stats.avgNurseRating ? stats.avgNurseRating.toFixed(1) : '0.0'
                },
                pagination: {
                    page: parseInt(page),
                    limit: parseInt(limit),
                    total: total,
                    pages: Math.ceil(total / parseInt(limit))
                }
            }
        });
    } catch (error) {
        console.error('Get all ratings error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

module.exports = router;
