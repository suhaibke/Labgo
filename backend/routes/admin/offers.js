const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Lab = require('../../models/Lab');
const { verifyToken } = require('../../middleware/auth');

// Admin role verification middleware for API routes
const adminOnly = async (req, res, next) => {
    if (req.userRole !== 'admin') {
        return res.status(403).json({
            success: false,
            message: 'Access denied. Admin role required.'
        });
    }
    next();
};

/**
 * GET /api/admin/offers
 * Get all offers from all labs with pagination and filtering
 * Query params:
 * - page: Page number (default: 1)
 * - limit: Items per page (default: 20)
 * - starred: Filter by starred status ('true' or 'false')
 * - labId: Filter by specific lab
 * - search: Search in offer name or lab name
 * - status: Filter by active/expired ('active', 'expired', 'all')
 */
router.get('/', verifyToken, adminOnly, async (req, res) => {
    try {
        const {
            page = 1,
            limit = 20,
            starred,
            labId,
            search,
            status = 'all'
        } = req.query;

        const skip = (parseInt(page) - 1) * parseInt(limit);
        const now = new Date();

        // Build aggregation pipeline to unwind offers
        const pipeline = [
            // Only active labs
            { $match: { status: 'Active' } },
            // Unwind offers array
            { $unwind: { path: '$offers', preserveNullAndEmptyArrays: false } },
            // Project needed fields
            {
                $project: {
                    labId: '$_id',
                    labName: '$name',
                    labCity: '$city',
                    labLogo: '$logo',
                    offer: '$offers'
                }
            }
        ];

        // Add labId filter if provided
        if (labId) {
            pipeline.splice(1, 0, { $match: { _id: new mongoose.Types.ObjectId(labId) } });
        }

        // Add starred filter if provided
        if (starred === 'true') {
            pipeline.push({ $match: { 'offer.isStarred': true } });
        } else if (starred === 'false') {
            pipeline.push({ $match: { 'offer.isStarred': { $ne: true } } });
        }

        // Add status filter (active/expired)
        if (status === 'active') {
            pipeline.push({
                $match: {
                    'offer.isActive': true,
                    $or: [
                        { 'offer.endDate': { $gte: now } },
                        { 'offer.endDate': null },
                        { 'offer.endDate': { $exists: false } }
                    ]
                }
            });
        } else if (status === 'expired') {
            pipeline.push({
                $match: {
                    $or: [
                        { 'offer.isActive': false },
                        { 'offer.endDate': { $lt: now } }
                    ]
                }
            });
        }

        // Add search filter if provided
        if (search) {
            pipeline.push({
                $match: {
                    $or: [
                        { 'offer.name': { $regex: search, $options: 'i' } },
                        { 'offer.nameAr': { $regex: search, $options: 'i' } },
                        { labName: { $regex: search, $options: 'i' } }
                    ]
                }
            });
        }

        // Sort: starred first, then by creation date
        pipeline.push({
            $sort: {
                'offer.isStarred': -1,
                'offer.starredAt': -1,
                'offer.createdAt': -1
            }
        });

        // Get total count before pagination
        const countPipeline = [...pipeline];
        countPipeline.push({ $count: 'total' });
        const countResult = await Lab.aggregate(countPipeline);
        const total = countResult[0]?.total || 0;

        // Add pagination
        pipeline.push({ $skip: skip });
        pipeline.push({ $limit: parseInt(limit) });

        const offers = await Lab.aggregate(pipeline);

        // Get statistics
        const statsPipeline = [
            { $match: { status: 'Active' } },
            { $unwind: { path: '$offers', preserveNullAndEmptyArrays: false } },
            {
                $group: {
                    _id: null,
                    totalOffers: { $sum: 1 },
                    starredOffers: {
                        $sum: { $cond: [{ $eq: ['$offers.isStarred', true] }, 1, 0] }
                    },
                    activeOffers: {
                        $sum: {
                            $cond: [
                                {
                                    $and: [
                                        { $eq: ['$offers.isActive', true] },
                                        {
                                            $or: [
                                                { $gte: ['$offers.endDate', now] },
                                                { $eq: ['$offers.endDate', null] },
                                                { $not: { $ifNull: ['$offers.endDate', false] } }
                                            ]
                                        }
                                    ]
                                },
                                1,
                                0
                            ]
                        }
                    }
                }
            }
        ];
        const statsResult = await Lab.aggregate(statsPipeline);
        const stats = statsResult[0] || { totalOffers: 0, starredOffers: 0, activeOffers: 0 };

        res.json({
            success: true,
            data: {
                offers,
                pagination: {
                    total,
                    page: parseInt(page),
                    limit: parseInt(limit),
                    pages: Math.ceil(total / parseInt(limit))
                },
                stats
            }
        });
    } catch (error) {
        console.error('Error fetching offers:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch offers',
            error: error.message
        });
    }
});

/**
 * PUT /api/admin/offers/:labId/:offerId/star
 * Toggle star status for an offer
 */
router.put('/:labId/:offerId/star', verifyToken, adminOnly, async (req, res) => {
    try {
        const { labId, offerId } = req.params;
        const { isStarred } = req.body;

        // Validate ObjectIds
        if (!mongoose.Types.ObjectId.isValid(labId) || !mongoose.Types.ObjectId.isValid(offerId)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid lab ID or offer ID'
            });
        }

        const lab = await Lab.findById(labId);
        if (!lab) {
            return res.status(404).json({
                success: false,
                message: 'Lab not found'
            });
        }

        const offer = lab.offers.id(offerId);
        if (!offer) {
            return res.status(404).json({
                success: false,
                message: 'Offer not found'
            });
        }

        // Update offer star status
        offer.isStarred = isStarred;
        offer.starredAt = isStarred ? new Date() : null;
        offer.starredBy = isStarred ? req.user.id : null;

        await lab.save();

        res.json({
            success: true,
            message: isStarred ? 'Offer starred successfully' : 'Offer unstarred successfully',
            data: {
                labId,
                offerId,
                isStarred: offer.isStarred,
                starredAt: offer.starredAt
            }
        });
    } catch (error) {
        console.error('Error toggling offer star:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update offer star status',
            error: error.message
        });
    }
});

/**
 * GET /api/admin/offers/labs
 * Get all labs for filter dropdown
 */
router.get('/labs', verifyToken, adminOnly, async (req, res) => {
    try {
        const labs = await Lab.find({ status: 'Active' })
            .select('name city')
            .sort({ name: 1 });

        res.json({
            success: true,
            data: labs
        });
    } catch (error) {
        console.error('Error fetching labs for offers:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch labs'
        });
    }
});

module.exports = router;
