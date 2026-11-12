const express = require('express');
const router = express.Router();
const User = require('../../models/User');
const Order = require('../../models/Order');
const Lab = require('../../models/Lab');
const NurseApplication = require('../../models/NurseApplication');
const Transaction = require('../../models/Transaction');

// Import admin authentication middleware
const auth = require('./middleware');

/**
 * GET /api/admin/dashboard/statistics
 * Main dashboard statistics endpoint
 * Returns comprehensive statistics for the admin dashboard
 */
router.get('/statistics', auth, async (req, res) => {
    try {
        // Get date ranges for calculations
        const now = new Date();
        const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

        // Execute all statistics queries in parallel for better performance
        const [
            overview,
            orders,
            nurses,
            labs,
            finance,
            trends,
            pendingApprovals
        ] = await Promise.all([
            getOverviewStats(todayStart, todayEnd, monthStart, weekAgo),
            getOrderStats(),
            getNurseStats(),
            getLabStats(),
            getFinanceStats(todayStart, monthStart),
            getTrends(weekAgo),
            getPendingApprovals()
        ]);

        res.json({
            success: true,
            data: {
                overview,
                orders,
                nurses,
                labs,
                finance,
                trends,
                pendingApprovals
            },
            lastUpdated: new Date()
        });
    } catch (error) {
        console.error('Dashboard statistics error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch dashboard statistics'
        });
    }
});

/**
 * GET /api/admin/dashboard/charts/activity
 * Chart data for activity visualization
 * Query params: period (day|week|month)
 */
router.get('/charts/activity', auth, async (req, res) => {
    try {
        const period = req.query.period || 'day';
        const now = new Date();
        let startDate;

        // Determine date range based on period
        switch (period) {
            case 'day':
                startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
                break;
            case 'week':
                startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
                break;
            case 'month':
                startDate = new Date(now.getFullYear(), now.getMonth(), 1);
                break;
            default:
                startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        }

        // Get patient registrations over time
        const patientRegistrations = await User.aggregate([
            {
                $match: {
                    role: 'patient',
                    createdAt: { $gte: startDate }
                }
            },
            {
                $group: {
                    _id: {
                        $dateToString: {
                            format: '%Y-%m-%d %H:00',
                            date: '$createdAt'
                        }
                    },
                    count: { $sum: 1 }
                }
            },
            { $sort: { _id: 1 } }
        ]);

        // Get orders completed over time
        const ordersCompleted = await Order.aggregate([
            {
                $match: {
                    status: 'completed',
                    createdAt: { $gte: startDate }
                }
            },
            {
                $group: {
                    _id: {
                        $dateToString: {
                            format: '%Y-%m-%d %H:00',
                            date: '$createdAt'
                        }
                    },
                    count: { $sum: 1 }
                }
            },
            { $sort: { _id: 1 } }
        ]);

        // Format data for Chart.js
        const labels = [...new Set([
            ...patientRegistrations.map(p => p._id),
            ...ordersCompleted.map(o => o._id)
        ])].sort();

        const patientData = labels.map(label => {
            const found = patientRegistrations.find(p => p._id === label);
            return found ? found.count : 0;
        });

        const ordersData = labels.map(label => {
            const found = ordersCompleted.find(o => o._id === label);
            return found ? found.count : 0;
        });

        res.json({
            success: true,
            data: {
                labels,
                datasets: [
                    {
                        label: 'Patient Registrations',
                        data: patientData,
                        borderColor: '#8378f4',
                        backgroundColor: 'rgba(131, 120, 244, 0.1)',
                        borderWidth: 2,
                        tension: 0.4,
                        fill: true
                    },
                    {
                        label: 'Tests Completed',
                        data: ordersData,
                        borderColor: '#f4a900',
                        backgroundColor: 'rgba(244, 169, 0, 0.1)',
                        borderWidth: 2,
                        tension: 0.4,
                        fill: true
                    }
                ]
            }
        });
    } catch (error) {
        console.error('Chart data error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch chart data'
        });
    }
});

/**
 * GET /api/admin/dashboard/recent-activity
 * Recent system activity including orders, registrations, etc.
 * Query params: limit (default: 10)
 */
router.get('/recent-activity', auth, async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 10;

        // Get recent orders with populated data
        const recentOrders = await Order.find()
            .populate('patientId', 'name email phone')
            .populate('labId', 'name')
            .populate('nurseId', 'name')
            .sort({ createdAt: -1 })
            .limit(limit);

        // Format activity data
        const activities = recentOrders.map(order => ({
            id: order._id,
            type: 'order',
            patientName: order.patientId?.name || 'Unknown',
            patientEmail: order.patientId?.email || '',
            testName: order.tests.length > 0
                ? (order.tests.length === 1
                    ? order.tests[0].testName
                    : `${order.tests.length} tests`)
                : 'No tests',
            status: order.status,
            urgency: order.urgency,
            date: order.createdAt,
            labName: order.labId?.name || 'Unassigned',
            nurseName: order.nurseId?.name || 'Unassigned'
        }));

        res.json({
            success: true,
            data: {
                activities,
                total: activities.length
            }
        });
    } catch (error) {
        console.error('Recent activity error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch recent activity'
        });
    }
});

/**
 * GET /api/admin/dashboard/quick-stats
 * Lightweight endpoint for header stats
 * Returns only the most critical metrics
 */
router.get('/quick-stats', auth, async (req, res) => {
    try {
        const now = new Date();
        const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        const yesterdayStart = new Date(todayStart.getTime() - 24 * 60 * 60 * 1000);

        // Parallel queries for quick stats
        const [
            totalPatients,
            todayOrders,
            yesterdayOrders,
            pendingOrders
        ] = await Promise.all([
            User.countDocuments({ role: 'patient' }),
            Order.countDocuments({ createdAt: { $gte: todayStart, $lt: todayEnd } }),
            Order.countDocuments({ createdAt: { $gte: yesterdayStart, $lt: todayStart } }),
            Order.countDocuments({ status: 'pending' })
        ]);

        // Calculate change percentage
        const ordersChange = yesterdayOrders > 0
            ? Math.round(((todayOrders - yesterdayOrders) / yesterdayOrders) * 100)
            : 0;

        res.json({
            success: true,
            data: {
                patients: totalPatients,
                todayOrders,
                pendingOrders,
                ordersChange
            }
        });
    } catch (error) {
        console.error('Quick stats error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch quick stats'
        });
    }
});

// ============================================================
// HELPER FUNCTIONS FOR STATISTICS AGGREGATION
// ============================================================

/**
 * Get overview statistics
 */
async function getOverviewStats(todayStart, todayEnd, monthStart, weekAgo) {
    const [
        totalPatients,
        totalTestsResult,
        pendingResults,
        todayAppointments,
        lastWeekPatients,
        revenueTodayResult,
        revenueMonthResult
    ] = await Promise.all([
        User.countDocuments({ role: 'patient' }),
        Order.aggregate([{ $unwind: '$tests' }, { $count: 'total' }]),
        Order.countDocuments({ status: 'at_lab' }),
        Order.countDocuments({ createdAt: { $gte: todayStart, $lt: todayEnd } }),
        User.countDocuments({
            role: 'patient',
            createdAt: { $gte: new Date(todayStart.getTime() - 7 * 24 * 60 * 60 * 1000) }
        }),
        Order.aggregate([
            {
                $match: {
                    'paymentCollected.collectedAt': { $gte: todayStart, $lt: todayEnd },
                    'financials.adminAmount': { $exists: true, $ne: null }
                }
            },
            { $group: { _id: null, total: { $sum: '$financials.adminAmount' } } }
        ]),
        Order.aggregate([
            {
                $match: {
                    'paymentCollected.collectedAt': { $gte: monthStart },
                    'financials.adminAmount': { $exists: true, $ne: null }
                }
            },
            { $group: { _id: null, total: { $sum: '$financials.adminAmount' } } }
        ])
    ]);

    const totalTests = totalTestsResult[0]?.total || 0;
    const revenueToday = revenueTodayResult[0]?.total || 0;
    const revenueMonth = revenueMonthResult[0]?.total || 0;

    // Calculate change percentage
    const patientsChange = lastWeekPatients > 0
        ? Math.round(((totalPatients - lastWeekPatients) / lastWeekPatients) * 100)
        : 0;

    return {
        totalPatients,
        totalTests,
        pendingResults,
        todayAppointments,
        revenueToday,
        revenueMonth,
        patientsChange
    };
}

/**
 * Get order statistics by status
 */
async function getOrderStats() {
    const stats = await Order.aggregate([
        {
            $group: {
                _id: null,
                pending: { $sum: { $cond: [{ $eq: ['$status', 'pending'] }, 1, 0] } },
                confirmed: { $sum: { $cond: [{ $eq: ['$status', 'confirmed'] }, 1, 0] } },
                inProgress: {
                    $sum: {
                        $cond: [
                            { $in: ['$status', ['nurse_assigned', 'sample_collected', 'at_lab']] },
                            1,
                            0
                        ]
                    }
                },
                completed: { $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] } },
                cancelled: { $sum: { $cond: [{ $eq: ['$status', 'cancelled'] }, 1, 0] } },
                urgent: { $sum: { $cond: [{ $eq: ['$urgency', 'urgent'] }, 1, 0] } }
            }
        }
    ]);

    return stats[0] || {
        pending: 0,
        confirmed: 0,
        inProgress: 0,
        completed: 0,
        cancelled: 0,
        urgent: 0
    };
}

/**
 * Get nurse statistics
 */
async function getNurseStats() {
    const [total, active, blocked, pendingApplications] = await Promise.all([
        User.countDocuments({ role: 'nurse' }),
        User.countDocuments({ role: 'nurse', status: 'active' }),
        User.countDocuments({ role: 'nurse', status: 'blocked' }),
        NurseApplication.countDocuments({ status: { $in: ['pending', 'under_review'] } })
    ]);

    return { total, active, blocked, pendingApplications };
}

/**
 * Get lab statistics
 */
async function getLabStats() {
    const [total, active, pending, suspended] = await Promise.all([
        Lab.countDocuments(),
        Lab.countDocuments({ status: 'Active' }),
        Lab.countDocuments({ status: 'Pending' }),
        Lab.countDocuments({ status: 'Suspended' })
    ]);

    return { total, active, pending, suspended };
}

/**
 * Get financial statistics
 */
async function getFinanceStats(todayStart, monthStart) {
    const [
        totalRevenueResult,
        pendingSettlementsResult,
        nurseBalancesResult
    ] = await Promise.all([
        Order.aggregate([
            {
                $match: {
                    status: { $nin: ['cancelled'] },
                    'financials.adminAmount': { $exists: true, $ne: null }
                }
            },
            { $group: { _id: null, total: { $sum: '$financials.adminAmount' } } }
        ]),
        Order.aggregate([
            {
                $match: {
                    'financials.adminSettled': false,
                    'financials.adminAmount': { $exists: true, $ne: null }
                }
            },
            { $group: { _id: null, total: { $sum: '$financials.adminAmount' } } }
        ]),
        User.aggregate([
            { $match: { role: 'nurse' } },
            { $group: { _id: null, total: { $sum: '$nurseBalance' } } }
        ])
    ]);

    const totalRevenue = totalRevenueResult[0]?.total || 0;
    const pendingSettlements = pendingSettlementsResult[0]?.total || 0;
    const nurseBalances = nurseBalancesResult[0]?.total || 0;

    return {
        totalRevenue,
        pendingSettlements,
        nurseBalances
    };
}

/**
 * Get trend data for charts
 */
async function getTrends(weekAgo) {
    const [patientRegistrations, ordersByDay] = await Promise.all([
        User.aggregate([
            { $match: { role: 'patient', createdAt: { $gte: weekAgo } } },
            {
                $group: {
                    _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
                    count: { $sum: 1 }
                }
            },
            { $sort: { _id: 1 } }
        ]),
        Order.aggregate([
            { $match: { createdAt: { $gte: weekAgo } } },
            {
                $group: {
                    _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
                    count: { $sum: 1 }
                }
            },
            { $sort: { _id: 1 } }
        ])
    ]);

    return {
        patientRegistrations,
        ordersByDay
    };
}

/**
 * Get pending approvals count
 */
async function getPendingApprovals() {
    const [labs, nurses, orders, lowRatings] = await Promise.all([
        Lab.countDocuments({ isVerified: false }),
        NurseApplication.countDocuments({ status: 'pending' }),
        Order.countDocuments({ status: 'pending' }),
        Order.countDocuments({
            $or: [
                { 'rating.labRating': { $lte: 3, $exists: true } },
                { 'rating.nurseRating': { $lte: 3, $exists: true } }
            ]
        })
    ]);

    return { labs, nurses, orders, lowRatings };
}

module.exports = router;
