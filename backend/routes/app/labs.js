const express = require('express');
const router = express.Router();
const Lab = require('../../models/Lab');

// Import authentication middleware
const { optionalAuth } = require('../../middleware/auth');

// All routes in this file use optional auth (allows guest browsing)
router.use(optionalAuth);

/**
 * GET /api/app/labs
 * Get all active labs for the app
 * Query params:
 * - city: Filter by city
 * - specialization: Filter by specialization
 * - search: Search in name, city, or address
 * - limit: Number of results per page (default: 20)
 * - skip: Number of results to skip (for pagination, default: 0)
 */
router.get('/', async (req, res) => {
    try {
        const {
            city,
            specialization,
            search,
            limit = 20,
            skip = 0
        } = req.query;

        // Build query filter
        const filter = { status: 'Active' };

        // Use exact match for city (important for Arabic city names)
        if (city) {
            filter.city = city;
        }

        if (specialization) {
            filter.specialization = specialization;
        }

        if (search) {
            filter.$or = [
                { name: new RegExp(search, 'i') },
                { city: new RegExp(search, 'i') },
                { address: new RegExp(search, 'i') }
            ];
        }

        // Execute query with pagination
        // Note: phone and email excluded for patient privacy - only admin/nurse/lab roles should see these
        const labs = await Lab.find(filter)
            .select('name address city country logo specialization status operatingHours averageRating totalReviews isVerified tests totalTestsPerformed coordinates')
            .limit(parseInt(limit))
            .skip(parseInt(skip))
            .sort({ averageRating: -1, totalReviews: -1 });

        // Get total count for pagination
        const total = await Lab.countDocuments(filter);

        res.json({
            success: true,
            message: 'Labs retrieved successfully',
            data: {
                labs,
                pagination: {
                    total,
                    limit: parseInt(limit),
                    skip: parseInt(skip),
                    hasMore: parseInt(skip) + parseInt(limit) < total
                }
            }
        });
    } catch (error) {
        console.error('Error fetching labs:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching labs',
            error: error.message
        });
    }
});

/**
 * GET /api/app/labs/featured
 * Get featured labs (selected by admin)
 * Query params:
 * - city: Filter by city (exact match)
 * - limit: Number of results (default: 10)
 */
router.get('/featured', async (req, res) => {
    try {
        const { limit = 10, city } = req.query;

        // Build query filter
        const filter = {
            status: 'Active',
            isFeatured: true
        };

        // Add city filter if provided (exact match for Arabic city names)
        if (city) {
            filter.city = city;
        }

        // Get labs marked as featured by admin
        const labs = await Lab.find(filter)
            .select('name address city country logo specialization status operatingHours averageRating totalReviews isVerified tests totalTestsPerformed featuredAt coordinates')
            .limit(parseInt(limit))
            .sort({ featuredAt: -1, averageRating: -1 });

        res.json({
            success: true,
            message: 'Featured labs retrieved successfully',
            data: {
                labs,
                count: labs.length
            }
        });
    } catch (error) {
        console.error('Error fetching featured labs:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching featured labs',
            error: error.message
        });
    }
});

/**
 * GET /api/app/labs/:id
 * Get details of a specific lab
 */
router.get('/:id', async (req, res) => {
    try {
        // Note: phone and email excluded for patient privacy - only admin/nurse/lab roles should see these
        const lab = await Lab.findById(req.params.id)
            .select('-phone -email -patientTests -createdBy -lastUpdatedBy');

        if (!lab) {
            return res.status(404).json({
                success: false,
                message: 'Lab not found'
            });
        }

        res.json({
            success: true,
            message: 'Lab retrieved successfully',
            data: lab
        });
    } catch (error) {
        console.error('Error fetching lab:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching lab',
            error: error.message
        });
    }
});

/**
 * GET /api/app/labs/:id/tests
 * Get all available tests for a specific lab
 */
router.get('/:id/tests', async (req, res) => {
    try {
        const lab = await Lab.findById(req.params.id)
            .select('name tests');

        if (!lab) {
            return res.status(404).json({
                success: false,
                message: 'Lab not found'
            });
        }

        res.json({
            success: true,
            message: 'Lab tests retrieved successfully',
            data: {
                labName: lab.name,
                tests: lab.tests
            }
        });
    } catch (error) {
        console.error('Error fetching lab tests:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching lab tests',
            error: error.message
        });
    }
});

/**
 * GET /api/app/labs/meta/specializations
 * Get all available specializations
 */
router.get('/meta/specializations', async (req, res) => {
    try {
        const specializations = [
            'Blood Tests',
            'X-Ray',
            'MRI',
            'CT Scan',
            'Ultrasound',
            'Pathology',
            'Microbiology',
            'Biochemistry',
            'Genetics',
            'Allergy',
            'Cardiology',
            'Neurology',
            'General'
        ];

        res.json({
            success: true,
            message: 'Specializations retrieved successfully',
            data: specializations
        });
    } catch (error) {
        console.error('Error fetching specializations:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching specializations',
            error: error.message
        });
    }
});

/**
 * GET /api/app/labs/offers
 * Get all labs with active offers
 * Query params:
 * - city: Filter by city (exact match)
 */
router.get('/offers/active', async (req, res) => {
    try {
        const { city } = req.query;
        const now = new Date();

        // Build query filter
        const filter = {
            status: 'Active',
            offers: {
                $elemMatch: {
                    isActive: true,
                    startDate: { $lte: now },
                    $or: [
                        { endDate: { $gte: now } },
                        { endDate: null },
                        { endDate: { $exists: false } }
                    ]
                }
            }
        };

        // Add city filter if provided (exact match for Arabic city names)
        if (city) {
            filter.city = city;
        }

        // Find labs with active offers
        // Use $elemMatch to ensure all conditions apply to the SAME offer element
        const labs = await Lab.find(filter)
        .select('name address city country logo specialization status operatingHours averageRating totalReviews isVerified tests offers coordinates')
        .sort({ averageRating: -1, totalReviews: -1 });

        // Filter and transform data to only include active offers
        const labsWithOffers = labs.map(lab => {
            const labObj = lab.toObject();
            
            // Filter to only active, valid offers
            labObj.activeOffers = (labObj.offers || []).filter(offer => {
                const isActive = offer.isActive;
                const notExpired = !offer.endDate || new Date(offer.endDate) >= now;
                const hasStarted = new Date(offer.startDate) <= now;
                return isActive && notExpired && hasStarted;
            });

            // Add offer count and best discount
            labObj.offerCount = labObj.activeOffers.length;
            if (labObj.activeOffers.length > 0) {
                labObj.bestDiscount = Math.max(...labObj.activeOffers.map(o => 
                    o.discountType === 'percentage' ? o.discountValue : 0
                ));
            }

            delete labObj.offers; // Remove full offers array, keep only activeOffers
            return labObj;
        }).filter(lab => lab.offerCount > 0); // Only return labs that actually have active offers

        res.json({
            success: true,
            message: 'Labs with offers retrieved successfully',
            data: {
                labs: labsWithOffers,
                count: labsWithOffers.length
            }
        });
    } catch (error) {
        console.error('Error fetching labs with offers:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching labs with offers',
            error: error.message
        });
    }
});

/**
 * GET /api/app/labs/:id/offers
 * Get active offers for a specific lab
 */
router.get('/:id/offers', async (req, res) => {
    try {
        const lab = await Lab.findById(req.params.id)
            .select('name offers tests');

        if (!lab) {
            return res.status(404).json({
                success: false,
                message: 'Lab not found'
            });
        }

        const now = new Date();

        // Filter active offers
        const activeOffers = (lab.offers || []).filter(offer => {
            const isActive = offer.isActive;
            const notExpired = !offer.endDate || new Date(offer.endDate) >= now;
            const hasStarted = new Date(offer.startDate) <= now;
            return isActive && notExpired && hasStarted;
        });

        // Enhance offers with test details
        const offersWithTests = activeOffers.map(offer => {
            const offerObj = offer.toObject();
            
            if (offerObj.applyToAllTests) {
                offerObj.applicableTestsDetails = lab.tests;
            } else {
                offerObj.applicableTestsDetails = lab.tests.filter(test => 
                    offerObj.applicableTests?.some(t => 
                        t.testId?.toString() === test._id.toString() || t.testCode === test.code
                    )
                );
            }
            
            return offerObj;
        });

        res.json({
            success: true,
            message: 'Lab offers retrieved successfully',
            data: {
                labName: lab.name,
                offers: offersWithTests,
                count: offersWithTests.length
            }
        });
    } catch (error) {
        console.error('Error fetching lab offers:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching lab offers',
            error: error.message
        });
    }
});

module.exports = router;
