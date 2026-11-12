const express = require('express');
const router = express.Router();
const Service = require('../../models/Service');
const Lab = require('../../models/Lab');
const { optionalAuth } = require('../../middleware/auth');

router.use(optionalAuth);

/**
 * GET /api/app/services
 * Active quick services for the home page shortcut row, ordered for display.
 */
router.get('/', async (req, res) => {
    try {
        const services = await Service.find({ isActive: true }).sort({ order: 1, createdAt: 1 });
        res.json({ success: true, data: { services } });
    } catch (error) {
        console.error('Get services error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

/**
 * GET /api/app/services/:id/labs
 * Labs that currently offer this service, with the matching test's price.
 */
router.get('/:id/labs', async (req, res) => {
    try {
        const { id } = req.params;
        const { city } = req.query;

        const filter = {
            status: 'Active',
            'tests.serviceId': id,
        };
        if (city) {
            // Restrict to labs in the patient's own governorate
            filter.city = city;
        }

        const labs = await Lab.find(filter)
            .select('name logo city country address averageRating totalRatings tests');

        const results = labs.map((lab) => {
            const matchingTest = lab.tests.find((t) => String(t.serviceId) === String(id));
            return {
                _id: lab._id,
                name: lab.name,
                logo: lab.logo,
                city: lab.city,
                country: lab.country,
                address: lab.address,
                averageRating: lab.averageRating,
                totalRatings: lab.totalRatings,
                test: matchingTest ? {
                    _id: matchingTest._id,
                    name: matchingTest.name,
                    price: matchingTest.price,
                } : null,
            };
        });

        res.json({ success: true, data: { labs: results } });
    } catch (error) {
        console.error('Get labs for service error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

module.exports = router;
