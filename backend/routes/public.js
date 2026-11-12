const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Order = require('../models/Order');
const Lab = require('../models/Lab');

/**
 * GET /api/public/stats
 * Public endpoint for landing page statistics
 * No authentication required
 */
router.get('/stats', async (req, res) => {
    try {
        // Execute all queries in parallel for performance
        const [
            patientCount,
            orderCount,
            nurseCount,
            labCount
        ] = await Promise.all([
            // Count active patients
            User.countDocuments({
                role: 'patient',
                status: 'active'
            }),
            // Count total orders (all-time, excluding cancelled)
            Order.countDocuments({
                status: { $ne: 'cancelled' }
            }),
            // Count active nurses
            User.countDocuments({
                role: 'nurse',
                status: 'active'
            }),
            // Count active labs
            Lab.countDocuments({
                status: 'Active'
            })
        ]);

        res.json({
            success: true,
            data: {
                patients: patientCount,
                orders: orderCount,
                nurses: nurseCount,
                labs: labCount,
                lastUpdated: new Date()
            }
        });
    } catch (error) {
        console.error('Public stats error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch statistics'
        });
    }
});

module.exports = router;
