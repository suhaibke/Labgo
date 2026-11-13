const express = require('express');
const router = express.Router();
const Lab = require('../../models/Lab');
const User = require('../../models/User');
const Order = require('../../models/Order');
const Package = require('../../models/Package');
const ExternalTransfer = require('../../models/ExternalTransfer');
const auth = require('./middleware');
const { cleanLicenseHolders } = require('../../helpers/license-holders');
const path = require('path');
const { __: translateHelper } = require('../../helpers/i18n-helper');
const { r2SingleUpload } = require('../../middleware/r2Upload');
const r2Service = require('../../services/r2Service');
const fcmService = require('../../services/fcmService');
const { cityToTopicKey } = require('../../utils/cities');
const {
    calculateAge,
    decorateOrderWithPatientInfo,
    getOrderPatientInfo
} = require('../../helpers/order-patient-info');

// R2 upload middleware for test results and imports
const uploadResult = r2SingleUpload('results', 'resultFile', 'result-');
const testImportUpload = r2SingleUpload('testImports', 'file', 'test-import-');
const testImageUpload = r2SingleUpload('tests', 'image', 'test-');
const uploadLabLogo = r2SingleUpload('labs', 'logo', 'lab-logo-');
const uploadLabCoverImage = r2SingleUpload('labs', 'coverImage', 'lab-cover-');

// Apply lab authentication middleware to all routes
router.use(auth);
router.use(require('./external-transfers'));
router.use(require('./results'));
router.use(require('./walk-in'));
router.use(require('./staff'));
router.use(require('./lab-finance-page'));
router.use(require('./lab-waste-page'));
router.use(require('./app-api'));
router.use(require('./transfers-in'));
router.use(require('./market-support'));

// Get lab dashboard data
router.get('/dashboard', async (req, res) => {
    try {
        const lab = req.lab;

        // ==================== REAL STATISTICS FROM ORDERS ====================
        // Get current date and calculate date ranges
        const now = new Date();
        const startOfThisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        const endOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 0);

        // Aggregate real statistics from orders
        const orderStats = await Order.aggregate([
            { $match: { labId: lab._id } },
            {
                $facet: {
                    // Total unique patients
                    uniquePatients: [
                        { $group: { _id: '$patientId' } },
                        { $count: 'count' }
                    ],
                    // Total tests performed (sum of tests array lengths)
                    totalTests: [
                        { $unwind: '$tests' },
                        { $count: 'count' }
                    ],
                    // This month's orders
                    thisMonth: [
                        { $match: { createdAt: { $gte: startOfThisMonth } } },
                        { $group: { _id: '$patientId' } },
                        { $count: 'patientCount' }
                    ],
                    // Last month's orders (for growth calculation)
                    lastMonth: [
                        { $match: { createdAt: { $gte: startOfLastMonth, $lte: endOfLastMonth } } },
                        { $group: { _id: '$patientId' } },
                        { $count: 'patientCount' }
                    ],
                    // This month's tests (for tests growth calculation)
                    thisMonthTests: [
                        { $match: { createdAt: { $gte: startOfThisMonth } } },
                        { $unwind: '$tests' },
                        { $count: 'testCount' }
                    ],
                    // Last month's tests (for tests growth calculation)
                    lastMonthTests: [
                        { $match: { createdAt: { $gte: startOfLastMonth, $lte: endOfLastMonth } } },
                        { $unwind: '$tests' },
                        { $count: 'testCount' }
                    ],
                    // This month's pending orders (for pending change calculation)
                    thisMonthPending: [
                        { $match: { createdAt: { $gte: startOfThisMonth }, status: { $in: ['pending', 'at_lab'] } } },
                        { $count: 'count' }
                    ],
                    // Last month's pending orders (for pending change calculation)
                    lastMonthPending: [
                        { $match: { createdAt: { $gte: startOfLastMonth, $lte: endOfLastMonth }, status: { $in: ['pending', 'at_lab'] } } },
                        { $count: 'count' }
                    ],
                    // Last month's rating (for rating change calculation)
                    lastMonthRating: [
                        { $match: {
                            createdAt: { $gte: startOfLastMonth, $lte: endOfLastMonth },
                            'rating.labRating': { $exists: true, $ne: null }
                        }},
                        { $group: { _id: null, avgRating: { $avg: '$rating.labRating' } } }
                    ],
                    // Orders by status
                    byStatus: [
                        { $group: { _id: '$status', count: { $sum: 1 } } }
                    ],
                    // Completed orders revenue
                    revenue: [
                        { $match: { status: 'completed' } },
                        { $group: { _id: null, total: { $sum: '$financials.labAmount' } } }
                    ],
                    // Average rating from completed orders
                    ratings: [
                        { $match: { 'rating.labRating': { $exists: true, $ne: null } } },
                        { $group: { _id: null, avgRating: { $avg: '$rating.labRating' }, count: { $sum: 1 } } }
                    ]
                }
            }
        ]);

        const aggregatedStats = orderStats[0] || {};

        // Extract values safely
        const totalPatientsServed = aggregatedStats.uniquePatients?.[0]?.count || 0;
        const totalTestsPerformed = aggregatedStats.totalTests?.[0]?.count || 0;
        const thisMonthPatients = aggregatedStats.thisMonth?.[0]?.patientCount || 0;
        const lastMonthPatients = aggregatedStats.lastMonth?.[0]?.patientCount || 0;
        const thisMonthTests = aggregatedStats.thisMonthTests?.[0]?.testCount || 0;
        const lastMonthTests = aggregatedStats.lastMonthTests?.[0]?.testCount || 0;
        const thisMonthPending = aggregatedStats.thisMonthPending?.[0]?.count || 0;
        const lastMonthPending = aggregatedStats.lastMonthPending?.[0]?.count || 0;
        const totalRevenue = aggregatedStats.revenue?.[0]?.total || 0;
        const avgRating = aggregatedStats.ratings?.[0]?.avgRating || lab.averageRating || 0;
        const totalRatings = aggregatedStats.ratings?.[0]?.count || lab.totalReviews || 0;
        const lastMonthRating = aggregatedStats.lastMonthRating?.[0]?.avgRating || avgRating;

        // Calculate growth percentages
        const patientGrowth = lastMonthPatients > 0
            ? ((thisMonthPatients - lastMonthPatients) / lastMonthPatients * 100).toFixed(1)
            : thisMonthPatients > 0 ? 100 : 0;

        const testsGrowth = lastMonthTests > 0
            ? ((thisMonthTests - lastMonthTests) / lastMonthTests * 100).toFixed(1)
            : thisMonthTests > 0 ? 100 : 0;

        const pendingChange = lastMonthPending > 0
            ? ((thisMonthPending - lastMonthPending) / lastMonthPending * 100).toFixed(1)
            : 0;

        const ratingChange = (avgRating - lastMonthRating).toFixed(1);

        // Count orders by status
        const statusCounts = {};
        (aggregatedStats.byStatus || []).forEach(s => { statusCounts[s._id] = s.count; });

        const pendingOrders = statusCounts.pending || 0;
        const inLabOrders = statusCounts.at_lab || 0;
        const completedOrders = statusCounts.completed || 0;

        // Calculate dashboard statistics
        const stats = {
            totalPatientsServed,
            totalTestsPerformed,
            averageRating: parseFloat(avgRating.toFixed(1)),
            totalReviews: totalRatings,
            activeTests: lab.tests.length,
            pendingPatientTests: pendingOrders + inLabOrders,
            inProgressPatientTests: inLabOrders,
            completedPatientTests: completedOrders,
            patientGrowth: parseFloat(patientGrowth),
            testsGrowth: parseFloat(testsGrowth),
            pendingChange: parseFloat(pendingChange),
            ratingChange: parseFloat(ratingChange),
            totalRevenue
        };

        // Get recent orders (last 10)
        const recentOrders = await Order.find({ labId: lab._id })
            .populate('patientId', 'name phone gender birthDate patientNo')
            .sort({ createdAt: -1 })
            .limit(10)
            .lean();

        // Map to recentTests format for compatibility
        const recentTests = recentOrders.map(order => ({
            _id: order._id,
            patientId: order.patientId?._id || order.patientId,
            testName: order.tests?.[0]?.testName || 'Multiple Tests',
            requestDate: order.createdAt,
            status: order.status === 'completed' ? 'Completed' :
                order.status === 'at_lab' ? 'In Progress' : 'Pending',
            patientInfo: getOrderPatientInfo(order)
        }));

        // Get tests by category
        const testsByCategory = {};
        lab.tests.forEach(test => {
            if (!testsByCategory[test.category]) {
                testsByCategory[test.category] = [];
            }
            testsByCategory[test.category].push(test);
        });

        // ==================== CURRENT MONTH DAILY STATISTICS ====================
        const startOfCurrentMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();

        const dailyAgg = await Order.aggregate([
            {
                $match: {
                    labId: lab._id,
                    createdAt: { $gte: startOfCurrentMonth }
                }
            },
            {
                $group: {
                    _id: {
                        year: { $year: '$createdAt' },
                        month: { $month: '$createdAt' },
                        day: { $dayOfMonth: '$createdAt' }
                    },
                    tests: { $sum: { $size: '$tests' } },
                    patients: { $addToSet: '$patientId' }
                }
            },
            {
                $project: {
                    _id: 1,
                    tests: 1,
                    patients: { $size: '$patients' },
                    date: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }
                }
            },
            { $sort: { '_id.year': 1, '_id.month': 1, '_id.day': 1 } }
        ]);

        // Build daily stats array for current month
        const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        const monthlyStats = [];

        // Generate all days of current month
        for (let day = 1; day <= daysInMonth; day++) {
            const date = new Date(now.getFullYear(), now.getMonth(), day);
            const dateStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;

            const dayData = dailyAgg.find(d => d.date === dateStr);

            monthlyStats.push({
                month: `${date.getDate()}`, // Show day number instead of month name
                tests: dayData?.tests || 0,
                patients: dayData?.patients || 0
            });
        }

        // Get language from cookie or default to Arabic
        const currentLang = req.cookies.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = ['ar'].includes(currentLang) ? 'Cairo, sans-serif' : 'Inter, sans-serif';

        res.render('dashboard/lab-dashboard', {
            lab,
            stats,
            recentTests,
            testsByCategory,
            monthlyStats,
            user: req.user,
            title: `${lab.name} Dashboard`,
            currentLang,
            direction,
            font,
            activeSection: 'overview'
        });

    } catch (error) {
        console.error('Dashboard error:', error);
        res.status(500).render('error', {
            message: 'Error loading dashboard',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get lab reports/analytics page
router.get('/reports', async (req, res) => {
    try {
        const lab = req.lab;

        // Get language from cookie or default to Arabic
        const currentLang = req.cookies.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = ['ar'].includes(currentLang) ? 'Cairo, sans-serif' : 'Inter, sans-serif';

        // Parse date filter from query params
        const { filter, startDate, endDate } = req.query;
        const now = new Date();

        // Calculate date range based on filter
        let dateFilter = {};
        let filterStartDate, filterEndDate;

        switch (filter) {
            case 'today':
                filterStartDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
                filterEndDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
                dateFilter = { createdAt: { $gte: filterStartDate, $lte: filterEndDate } };
                break;
            case 'week':
                const dayOfWeek = now.getDay();
                filterStartDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - dayOfWeek);
                filterEndDate = now;
                dateFilter = { createdAt: { $gte: filterStartDate, $lte: filterEndDate } };
                break;
            case 'month':
                filterStartDate = new Date(now.getFullYear(), now.getMonth(), 1);
                filterEndDate = now;
                dateFilter = { createdAt: { $gte: filterStartDate, $lte: filterEndDate } };
                break;
            case 'custom':
                if (startDate && endDate) {
                    filterStartDate = new Date(startDate);
                    filterEndDate = new Date(endDate);
                    filterEndDate.setHours(23, 59, 59);
                    dateFilter = { createdAt: { $gte: filterStartDate, $lte: filterEndDate } };
                }
                break;
            default:
                // 'all' - no date filter
                dateFilter = {};
        }

        // Base match criteria
        const baseMatch = { labId: lab._id, ...dateFilter };

        // For comparison purposes (last month stats)
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        const endOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 0);
        const sixMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 5, 1);

        // ==================== COMPREHENSIVE ANALYTICS ====================
        const analytics = await Order.aggregate([
            { $match: baseMatch },
            {
                $facet: {
                    // Overview stats
                    overview: [
                        {
                            $group: {
                                _id: null,
                                totalOrders: { $sum: 1 },
                                totalRevenue: { $sum: '$financials.labAmount' },
                                totalTests: { $sum: { $size: '$tests' } },
                                uniquePatients: { $addToSet: '$patientId' }
                            }
                        },
                        {
                            $project: {
                                totalOrders: 1,
                                totalRevenue: 1,
                                totalTests: 1,
                                uniquePatients: { $size: '$uniquePatients' }
                            }
                        }
                    ],
                    // This month stats
                    thisMonth: [
                        { $match: { createdAt: { $gte: startOfMonth } } },
                        {
                            $group: {
                                _id: null,
                                orders: { $sum: 1 },
                                revenue: { $sum: '$financials.labAmount' },
                                patients: { $addToSet: '$patientId' }
                            }
                        },
                        { $project: { orders: 1, revenue: 1, patients: { $size: '$patients' } } }
                    ],
                    // Last month stats
                    lastMonth: [
                        { $match: { createdAt: { $gte: startOfLastMonth, $lte: endOfLastMonth } } },
                        {
                            $group: {
                                _id: null,
                                orders: { $sum: 1 },
                                revenue: { $sum: '$financials.labAmount' },
                                patients: { $addToSet: '$patientId' }
                            }
                        },
                        { $project: { orders: 1, revenue: 1, patients: { $size: '$patients' } } }
                    ],
                    // Orders by status
                    byStatus: [
                        { $group: { _id: '$status', count: { $sum: 1 } } }
                    ],
                    // Most popular tests
                    popularTests: [
                        { $unwind: '$tests' },
                        { $group: { _id: '$tests.testName', count: { $sum: 1 }, revenue: { $sum: '$tests.price' } } },
                        { $sort: { count: -1 } },
                        { $limit: 10 }
                    ],
                    // Rating stats
                    ratings: [
                        { $match: { 'rating.labRating': { $exists: true, $ne: null } } },
                        {
                            $group: {
                                _id: null,
                                avgRating: { $avg: '$rating.labRating' },
                                totalRatings: { $sum: 1 },
                                rating5: { $sum: { $cond: [{ $eq: ['$rating.labRating', 5] }, 1, 0] } },
                                rating4: { $sum: { $cond: [{ $gte: ['$rating.labRating', 4] }, { $cond: [{ $lt: ['$rating.labRating', 5] }, 1, 0] }, 0] } },
                                rating3: { $sum: { $cond: [{ $gte: ['$rating.labRating', 3] }, { $cond: [{ $lt: ['$rating.labRating', 4] }, 1, 0] }, 0] } },
                                ratingBelow3: { $sum: { $cond: [{ $lt: ['$rating.labRating', 3] }, 1, 0] } }
                            }
                        }
                    ],
                    // Completed orders stats
                    completedStats: [
                        { $match: { status: 'completed' } },
                        {
                            $group: {
                                _id: null,
                                count: { $sum: 1 },
                                revenue: { $sum: '$financials.labAmount' }
                            }
                        }
                    ]
                }
            }
        ]);

        // Monthly revenue trend (last 6 months)
        const monthlyTrend = await Order.aggregate([
            { $match: { labId: lab._id, createdAt: { $gte: sixMonthsAgo } } },
            {
                $group: {
                    _id: { year: { $year: '$createdAt' }, month: { $month: '$createdAt' } },
                    orders: { $sum: 1 },
                    revenue: { $sum: '$financials.labAmount' },
                    tests: { $sum: { $size: '$tests' } },
                    patients: { $addToSet: '$patientId' }
                }
            },
            { $project: { _id: 1, orders: 1, revenue: 1, tests: 1, patients: { $size: '$patients' } } },
            { $sort: { '_id.year': 1, '_id.month': 1 } }
        ]);

        // Extract data
        const data = analytics[0] || {};
        const overview = data.overview?.[0] || { totalOrders: 0, totalRevenue: 0, totalTests: 0, uniquePatients: 0 };
        const thisMonthData = data.thisMonth?.[0] || { orders: 0, revenue: 0, patients: 0 };
        const lastMonthData = data.lastMonth?.[0] || { orders: 0, revenue: 0, patients: 0 };
        const ratingData = data.ratings?.[0] || { avgRating: 0, totalRatings: 0, rating5: 0, rating4: 0, rating3: 0, ratingBelow3: 0 };
        const completedData = data.completedStats?.[0] || { count: 0, revenue: 0 };

        // Calculate growth rates
        const orderGrowth = lastMonthData.orders > 0
            ? ((thisMonthData.orders - lastMonthData.orders) / lastMonthData.orders * 100).toFixed(1)
            : thisMonthData.orders > 0 ? 100 : 0;
        const revenueGrowth = lastMonthData.revenue > 0
            ? ((thisMonthData.revenue - lastMonthData.revenue) / lastMonthData.revenue * 100).toFixed(1)
            : thisMonthData.revenue > 0 ? 100 : 0;

        // Build monthly chart data
        const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        const chartData = [];
        for (let i = 5; i >= 0; i--) {
            const date = new Date(now.getFullYear(), now.getMonth() - i, 1);
            const monthData = monthlyTrend.find(m => m._id.year === date.getFullYear() && m._id.month === date.getMonth() + 1);

            // Ensure data exists and has valid values
            const dataPoint = {
                month: monthNames[date.getMonth()],
                orders: monthData?.orders || 0,
                revenue: monthData?.revenue || 0,
                tests: monthData?.tests || 0,
                patients: monthData?.patients || 0
            };

            chartData.push(dataPoint);
        }

        // Validate chartData has at least some data
        const hasValidChartData = chartData.some(d => d.orders > 0 || d.tests > 0);

        // Completion rate
        const completionRate = overview.totalOrders > 0
            ? ((completedData.count / overview.totalOrders) * 100).toFixed(1)
            : 0;

        // Average order value
        const avgOrderValue = completedData.count > 0
            ? (completedData.revenue / completedData.count).toFixed(0)
            : 0;

        res.render('dashboard/lab-reports', {
            lab,
            user: req.user,
            title: `${__('navigation.reports', currentLang)} - ${lab.name}`,
            currentLang,
            direction,
            font,
            activeSection: 'reports',
            // Overview stats
            overview,
            thisMonth: thisMonthData,
            lastMonth: lastMonthData,
            orderGrowth: parseFloat(orderGrowth),
            revenueGrowth: parseFloat(revenueGrowth),
            // Chart data
            chartData,
            // Status breakdown
            statusBreakdown: data.byStatus?.filter(s => s.count > 0) || [],
            // Popular tests
            popularTests: data.popularTests || [],
            // Rating data
            ratingData,
            // Other metrics
            completionRate: parseFloat(completionRate),
            avgOrderValue: parseInt(avgOrderValue)
        });

    } catch (error) {
        console.error('Reports page error:', error);
        res.status(500).render('error', {
            message: 'Error loading reports',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get single order details page
router.get('/orders/:orderId', async (req, res) => {
    try {
        const lab = req.lab;
        const { orderId } = req.params;

        // Get language from cookie or default to Arabic
        const currentLang = req.cookies.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = ['ar'].includes(currentLang) ? 'Cairo, sans-serif' : 'Inter, sans-serif';

        const order = await Order.findById(orderId)
            .populate('patientId', 'name phone email gender birthDate patientNo')
            .populate('nurseId', 'name phone email');

        if (!order) {
            return res.status(404).render('error', {
                message: 'Order not found',
                error: null
            });
        }

        // Verify order belongs to this lab
        if (order.labId.toString() !== lab._id.toString()) {
            return res.status(403).render('error', {
                message: 'This order does not belong to your lab',
                error: null
            });
        }

        const externalTransfer = await ExternalTransfer.findOne({ orderId: order._id });

        res.render('dashboard/lab-order-details', {
            lab,
            order,
            externalTransfer,
            patientInfo: getOrderPatientInfo(order),
            user: req.user,
            title: `${__('orders.orderDetails', currentLang)} - ${order.qrCode}`,
            currentLang,
            direction,
            font,
            activeSection: 'orders'
        });

    } catch (error) {
        console.error('Order details page error:', error);
        res.status(500).render('error', {
            message: 'Error loading order details',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get lab orders management page
router.get('/orders', async (req, res) => {
    try {
        const lab = req.lab;

        // Get language from cookie or default to Arabic
        const currentLang = req.cookies.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = ['ar'].includes(currentLang) ? 'Cairo, sans-serif' : 'Inter, sans-serif';

        // Get order counts for stats
        const incomingCount = await Order.countDocuments({ labId: lab._id, status: 'sample_collected' });
        const inLabCount = await Order.countDocuments({ labId: lab._id, status: 'at_lab' });
        const completedCount = await Order.countDocuments({ labId: lab._id, status: 'completed' });

        res.render('dashboard/lab-orders', {
            lab,
            user: req.user,
            title: __('labOrders.title', currentLang) + ' - ' + lab.name,
            currentLang,
            direction,
            font,
            activeSection: 'orders',
            stats: {
                incoming: incomingCount,
                inLab: inLabCount,
                completed: completedCount
            }
        });

    } catch (error) {
        console.error('Orders page error:', error);
        res.status(500).render('error', {
            message: 'Error loading orders page',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Upload test result file
router.post('/api/orders/:orderId/upload-result', ...uploadResult, async (req, res) => {
    try {
        const lab = req.lab;
        const { orderId } = req.params;

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Verify order belongs to this lab
        if (order.labId.toString() !== lab._id.toString()) {
            return res.status(403).json({
                success: false,
                message: 'This order does not belong to your lab'
            });
        }

        if (!req.file || !req.file.r2Url) {
            return res.status(400).json({
                success: false,
                message: 'No file uploaded'
            });
        }

        // Return the R2 file URL
        const fileUrl = req.file.r2Url;

        res.json({
            success: true,
            message: 'File uploaded successfully',
            data: {
                fileUrl: fileUrl
            }
        });

    } catch (error) {
        console.error('Upload result error:', error);
        res.status(500).json({
            success: false,
            message: 'Error uploading file',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get lab tests management
router.get('/tests', async (req, res) => {
    try {
        const lab = req.lab;

        // Get language from cookie or default to Arabic
        const currentLang = req.cookies.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = ['ar'].includes(currentLang) ? 'Cairo, sans-serif' : 'Inter, sans-serif';

        res.render('dashboard/lab-tests', {
            lab,
            tests: lab.tests,
            labSpecializations: lab.specialization || [],
            availableSpecializations: ['Blood Tests', 'X-Ray', 'MRI', 'CT Scan', 'Ultrasound', 'Pathology', 'Microbiology', 'Biochemistry', 'Genetics', 'Allergy', 'Cardiology', 'Neurology', 'General'],
            user: req.user,
            title: 'Manage Tests - ' + lab.name,
            currentLang,
            direction,
            font,
            activeSection: 'tests'
        });

    } catch (error) {
        console.error('Tests management error:', error);
        res.status(500).render('error', {
            message: 'Error loading tests management',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get lab quick-services adoption page
router.get('/services', async (req, res) => {
    try {
        const lab = req.lab;

        const currentLang = req.cookies.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = ['ar'].includes(currentLang) ? 'Cairo, sans-serif' : 'Inter, sans-serif';

        res.render('dashboard/lab-services', {
            lab,
            user: req.user,
            title: 'Quick Services - ' + lab.name,
            currentLang,
            direction,
            font,
            activeSection: 'services'
        });
    } catch (error) {
        console.error('Lab services page error:', error);
        res.status(500).render('error', {
            message: 'Error loading services page',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get lab orders history (completed orders)
router.get('/patient-tests', async (req, res) => {
    try {
        const lab = req.lab;

        // Get language from cookie or default to Arabic
        const currentLang = req.cookies.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = ['ar'].includes(currentLang) ? 'Cairo, sans-serif' : 'Inter, sans-serif';

        // Get completed order statistics
        const Order = require('../../models/Order');
        const stats = await Order.aggregate([
            {
                $match: { labId: lab._id, status: 'completed' }
            },
            {
                $group: {
                    _id: null,
                    total: { $sum: 1 },
                    thisMonth: {
                        $sum: {
                            $cond: [{
                                $gte: ['$results.completedAt', new Date(new Date().setDate(1))]
                            }, 1, 0]
                        }
                    },
                    revenue: { $sum: '$financials.labAmount' } // Lab's share instead of total
                }
            }
        ]);

        // Use translation helper
        const { __: translateHelper } = require('../../helpers/i18n-helper');

        res.render('dashboard/lab-patient-tests', {
            lab,
            user: req.user,
            title: `${translateHelper('ordersHistory.title', currentLang)} - ${lab.name}`,
            currentLang,
            direction,
            font,
            activeSection: 'patient-tests',
            stats: stats[0] || { total: 0, thisMonth: 0, revenue: 0 }
        });

    } catch (error) {
        console.error('Orders history page error:', error);
        res.status(500).render('error', {
            message: 'Error loading orders history',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get user profile
router.get('/profile', async (req, res) => {
    try {
        const user = req.user;

        // Get language from cookie or default to Arabic
        const currentLang = req.cookies.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = ['ar'].includes(currentLang) ? 'Cairo, sans-serif' : 'Inter, sans-serif';

        res.render('dashboard/lab-profile', {
            user: user,
            title: 'My Profile - ' + user.name,
            currentLang,
            direction,
            font,
            activeSection: 'profile'
        });

    } catch (error) {
        console.error('User profile error:', error);
        res.status(500).render('error', {
            message: 'Error loading user profile',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Update lab profile (API endpoint)
router.put('/api/profile', async (req, res) => {
    try {
        const lab = req.lab;
        const updateData = req.body;


        // Validate required fields
        const requiredFields = ['name', 'email', 'phone', 'address', 'city', 'country'];
        const missingFields = requiredFields.filter(field => !updateData[field] || updateData[field].trim() === '');

        if (missingFields.length > 0) {
            return res.status(400).json({
                success: false,
                message: `Required fields missing: ${missingFields.join(', ')}`
            });
        }

        // Fields that can be updated
        const allowedUpdates = [
            'name', 'email', 'phone', 'address', 'city', 'country',
            'website', 'logo', 'specialization', 'operatingHours',
            'description', 'coordinates', 'licenseHolders'
        ];

        // Only update allowed fields
        Object.keys(updateData).forEach(key => {
            if (allowedUpdates.includes(key) && updateData[key] !== undefined) {
                if (key === 'email') {
                    lab[key] = updateData[key].toLowerCase().trim();
                } else if (key === 'phone') {
                    lab[key] = updateData[key].trim();
                } else if (key === 'licenseHolders') {
                    lab[key] = cleanLicenseHolders(updateData[key]);
                } else if (key === 'specialization') {
                    // Ensure specialization is an array and not empty
                    const specArray = Array.isArray(updateData[key]) ? updateData[key] : [];
                    lab[key] = specArray.length > 0 ? specArray : ['Blood Tests'];
                } else {
                    lab[key] = updateData[key];
                }
            }
        });

        // Update metadata
        lab.lastUpdatedBy = req.user._id;

        await lab.save();

        res.json({
            success: true,
            message: 'Lab profile updated successfully',
            lab: lab
        });

    } catch (error) {
        console.error('Update lab profile error:', error);

        // Handle validation errors
        if (error.name === 'ValidationError') {
            const errors = Object.values(error.errors).map(err => err.message);
            return res.status(400).json({
                success: false,
                message: 'Validation error: ' + errors.join(', ')
            });
        }

        // Handle duplicate email/phone errors
        if (error.code === 11000) {
            const field = Object.keys(error.keyValue)[0];
            return res.status(400).json({
                success: false,
                message: `${field} already exists. Please use a different ${field}.`
            });
        }

        // Handle other mongoose errors
        if (error.name === 'CastError') {
            return res.status(400).json({
                success: false,
                message: 'Invalid data format provided'
            });
        }

        res.status(500).json({
            success: false,
            message: 'Error updating lab profile',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Upload/replace the lab's logo
router.post('/api/profile/logo', ...uploadLabLogo, async (req, res) => {
    try {
        if (!req.file || !req.file.r2Url) {
            return res.status(400).json({ success: false, message: 'No image file provided' });
        }

        const lab = req.lab;
        if (lab.logo) {
            await r2Service.deleteFile(lab.logo);
        }
        lab.logo = req.file.r2Url;
        lab.lastUpdatedBy = req.user._id;
        await lab.save();

        res.json({ success: true, message: 'Logo updated successfully', data: { logo: lab.logo } });
    } catch (error) {
        console.error('Upload lab logo error:', error);
        res.status(500).json({ success: false, message: 'Error uploading logo' });
    }
});

// Upload/replace the lab's public-profile cover image
router.post('/api/profile/cover-image', ...uploadLabCoverImage, async (req, res) => {
    try {
        if (!req.file || !req.file.r2Url) {
            return res.status(400).json({ success: false, message: 'No image file provided' });
        }

        const lab = req.lab;
        if (lab.coverImage) {
            await r2Service.deleteFile(lab.coverImage);
        }
        lab.coverImage = req.file.r2Url;
        lab.lastUpdatedBy = req.user._id;
        await lab.save();

        res.json({ success: true, message: 'Cover image updated successfully', data: { coverImage: lab.coverImage } });
    } catch (error) {
        console.error('Upload lab cover image error:', error);
        res.status(500).json({ success: false, message: 'Error uploading cover image' });
    }
});

// Upload lab logo (API endpoint)
router.post('/api/upload-logo', async (req, res) => {
    try {
        // This would typically handle file upload
        // For now, we'll simulate a logo update
        const { logoUrl } = req.body;

        if (!logoUrl) {
            return res.status(400).json({
                success: false,
                message: 'Logo URL is required'
            });
        }

        req.lab.logo = logoUrl;
        req.lab.lastUpdatedBy = req.user._id;
        await req.lab.save();

        res.json({
            success: true,
            message: 'Logo updated successfully',
            logo: req.lab.logo
        });

    } catch (error) {
        console.error('Upload logo error:', error);
        res.status(500).json({
            success: false,
            message: 'Error uploading logo',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get lab profile settings
router.get('/settings', async (req, res) => {
    try {
        const lab = req.lab;

        // Get language from cookie or default to Arabic
        const currentLang = req.cookies.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = ['ar'].includes(currentLang) ? 'Cairo, sans-serif' : 'Inter, sans-serif';

        // Available options for dropdowns
        const availableSpecializations = [
            'Blood Tests', 'X-Ray', 'MRI', 'CT Scan', 'Ultrasound',
            'Pathology', 'Microbiology', 'Biochemistry', 'Genetics',
            'Allergy', 'Cardiology', 'Neurology', 'General'
        ];

        const paymentMethods = ['Cash', 'Credit Card', 'Insurance', 'Online Payment'];

        res.render('dashboard/lab-settings', {
            lab,
            availableSpecializations,
            paymentMethods,
            user: req.user,
            title: 'Lab Settings - ' + lab.name,
            currentLang,
            direction,
            font,
            activeSection: 'settings'
        });

    } catch (error) {
        console.error('Lab settings error:', error);
        res.status(500).render('error', {
            message: 'Error loading lab settings',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Update user profile (API endpoint)
router.put('/api/user/profile', async (req, res) => {
    try {
        const user = req.user;
        const updateData = req.body;

        // Handle password change if provided
        if (updateData.currentPassword && updateData.newPassword) {

            // Validate inputs
            if (!user) {
                return res.status(400).json({
                    success: false,
                    message: 'User account not found'
                });
            }

            if (!user.password) {
                return res.status(400).json({
                    success: false,
                    message: 'User password not set - please contact support'
                });
            }

            if (!updateData.currentPassword || !updateData.newPassword) {
                return res.status(400).json({
                    success: false,
                    message: 'Current password and new password are required'
                });
            }

            // Verify current password
            const bcrypt = require('bcryptjs');
            const isPasswordValid = await bcrypt.compare(updateData.currentPassword, user.password);

            if (!isPasswordValid) {
                return res.status(400).json({
                    success: false,
                    message: 'Current password is incorrect'
                });
            }

            // Update password
            const salt = await bcrypt.genSalt(12);
            updateData.password = await bcrypt.hash(updateData.newPassword, salt);

            // Remove password fields from response
            delete updateData.currentPassword;
            delete updateData.newPassword;
        } else {
            // Don't update password if not provided
            delete updateData.currentPassword;
            delete updateData.newPassword;
        }

        // Update user fields
        ['name', 'phone', 'gender', 'birthDate'].forEach(field => {
            if (updateData[field]) {
                user[field] = updateData[field];
            }
        });

        if (updateData.password) {
            user.password = updateData.password;
        }

        await user.save();

        // Remove password from response
        const userResponse = user.toObject();
        delete userResponse.password;

        res.json({
            success: true,
            message: 'User profile updated successfully',
            user: userResponse
        });

    } catch (error) {
        console.error('User profile update error:', error);
        res.status(500).json({
            success: false,
            message: 'Error updating user profile',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// API endpoint to get lab statistics (for AJAX calls)
router.get('/api/stats', async (req, res) => {
    try {
        const lab = req.lab;

        const stats = {
            totalPatientsServed: lab.totalPatientsServed || 0,
            totalTestsPerformed: lab.totalTestsPerformed || 0,
            averageRating: lab.averageRating || 0,
            totalReviews: lab.totalReviews || 0,
            activeTests: lab.tests.length,
            pendingPatientTests: lab.patientTests.filter(test => test.status === 'Pending').length,
            inProgressPatientTests: lab.patientTests.filter(test => test.status === 'In Progress').length,
            completedPatientTests: lab.patientTests.filter(test => test.status === 'Completed').length,
            urgentTests: lab.patientTests.filter(test => test.urgency === 'Emergency' || test.urgency === 'Urgent').length
        };

        res.json({
            success: true,
            data: stats
        });

    } catch (error) {
        console.error('API stats error:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching lab statistics',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// API endpoint to add a new test
router.post('/api/tests', ...testImageUpload, async (req, res) => {
    try {
        const lab = req.lab;
        const { name, nameAr, code, price, category, description, instructions } = req.body;

        // Validate required fields
        if (!name || !nameAr || !price || !category) {
            return res.status(400).json({
                success: false,
                message: 'Arabic name, English name, price, and category are required'
            });
        }

        // Generate unique test code if not provided
        const testCode = code || `${category.toUpperCase().replace(/\s+/g, '_')}_${Date.now()}`;

        const newTest = {
            name: name.trim(),
            nameAr: nameAr.trim(),
            code: testCode,
            price: Math.round(parseFloat(price)),
            category: category.trim(),
            description: description?.trim() || '',
            instructions: instructions?.trim() || '',
            image: req.file?.r2Url || null,
        };

        // Add test to lab
        lab.tests.push(newTest);
        await lab.save();

        // Get the added test (it will be the last one)
        const addedTest = lab.tests[lab.tests.length - 1];

        res.status(201).json({
            success: true,
            message: 'Test added successfully',
            test: addedTest
        });

    } catch (error) {
        console.error('Add test error:', error);
        res.status(500).json({
            success: false,
            message: 'Error adding test',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// ==================== QUICK SERVICES (admin-managed catalog) ====================

// List active quick services the lab can adopt, with this lab's adoption status
router.get('/api/services', async (req, res) => {
    try {
        const Service = require('../../models/Service');
        const lab = req.lab;

        const services = await Service.find({ isActive: true }).sort({ order: 1, createdAt: 1 });

        const result = services.map((service) => {
            const adoptedTest = lab.tests.find((t) => String(t.serviceId) === String(service._id));
            return {
                _id: service._id,
                name: service.name,
                nameAr: service.nameAr,
                icon: service.icon,
                adopted: !!adoptedTest,
                testId: adoptedTest ? adoptedTest._id : null,
                testName: adoptedTest ? (adoptedTest.nameAr || adoptedTest.name) : null,
                price: adoptedTest ? adoptedTest.price : null,
            };
        });

        // This lab's own tests, for the adoption picker - only tests not
        // already linked to a (different) service can be picked.
        const availableTests = lab.tests
            .filter((t) => !t.serviceId)
            .map((t) => ({ _id: t._id, name: t.name, nameAr: t.nameAr, code: t.code, price: t.price }));

        res.json({ success: true, data: { services: result, availableTests } });
    } catch (error) {
        console.error('List lab services error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Adopt a service - links one of this lab's own existing tests to it
router.post('/api/services/:id/adopt', async (req, res) => {
    try {
        const Service = require('../../models/Service');
        const lab = req.lab;
        const { id } = req.params;
        const { testId } = req.body;

        if (!testId) {
            return res.status(400).json({ success: false, message: 'testId is required' });
        }

        const service = await Service.findById(id);
        if (!service || !service.isActive) {
            return res.status(404).json({ success: false, message: 'Service not found' });
        }

        const test = lab.tests.id(testId);
        if (!test) {
            return res.status(404).json({ success: false, message: 'Test not found' });
        }
        if (test.serviceId && String(test.serviceId) !== String(id)) {
            return res.status(400).json({ success: false, message: 'This test is already linked to another service' });
        }

        // Unlink any other test previously linked to this service before relinking.
        const previouslyLinked = lab.tests.find((t) => String(t.serviceId) === String(id) && String(t._id) !== String(testId));
        if (previouslyLinked) {
            previouslyLinked.serviceId = null;
        }

        test.serviceId = service._id;
        await lab.save();

        res.json({ success: true, message: 'Service adopted successfully' });
    } catch (error) {
        console.error('Adopt service error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Stop offering a service - unlinks the test (keeps the test itself intact)
router.delete('/api/services/:id/adopt', async (req, res) => {
    try {
        const lab = req.lab;
        const { id } = req.params;

        const test = lab.tests.find((t) => String(t.serviceId) === String(id));
        if (!test) {
            return res.status(404).json({ success: false, message: 'This service is not currently adopted' });
        }

        test.serviceId = null;
        await lab.save();

        res.json({ success: true, message: 'Service removed' });
    } catch (error) {
        console.error('Remove adopted service error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// API endpoint to get a single test
router.get('/api/tests/:testId', async (req, res) => {
    try {
        const lab = req.lab;
        const { testId } = req.params;

        const test = lab.tests.id(testId) || lab.tests.find(t => t._id.toString() === testId);
        if (!test) {
            return res.status(404).json({
                success: false,
                message: 'Test not found'
            });
        }

        res.json({
            success: true,
            test: test
        });

    } catch (error) {
        console.error('Get test error:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching test',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// API endpoint to update a test
router.put('/api/tests/:testId', ...testImageUpload, async (req, res) => {
    try {
        const lab = req.lab;
        const { testId } = req.params;
        const { name, nameAr, price, category, description, instructions, removeImage } = req.body;

        const testIndex = lab.tests.findIndex(t => t._id.toString() === testId);
        if (testIndex === -1) {
            return res.status(404).json({
                success: false,
                message: 'Test not found'
            });
        }

        // Update test fields
        if (name) lab.tests[testIndex].name = name.trim();
        if (nameAr !== undefined) lab.tests[testIndex].nameAr = String(nameAr).trim();
        if (price) lab.tests[testIndex].price = Math.round(parseFloat(price));
        if (category) lab.tests[testIndex].category = category.trim();
        if (description !== undefined) lab.tests[testIndex].description = description.trim();
        if (instructions !== undefined) lab.tests[testIndex].instructions = instructions.trim();
        if (req.file?.r2Url) {
            lab.tests[testIndex].image = req.file.r2Url;
        } else if (removeImage === 'true' || removeImage === true) {
            lab.tests[testIndex].image = null;
        }

        // Update metadata
        lab.tests[testIndex].lastUpdatedBy = req.user._id;
        lab.tests[testIndex].updatedAt = new Date();

        await lab.save();

        res.json({
            success: true,
            message: 'Test updated successfully',
            test: lab.tests[testIndex]
        });

    } catch (error) {
        console.error('Update test error:', error);
        res.status(500).json({
            success: false,
            message: 'Error updating test',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// API endpoint to delete a test
router.delete('/api/tests/:testId', async (req, res) => {
    try {
        const lab = req.lab;
        const { testId } = req.params;

        const testIndex = lab.tests.findIndex(t => t._id.toString() === testId);
        if (testIndex === -1) {
            return res.status(404).json({
                success: false,
                message: 'Test not found'
            });
        }

        // Remove test
        lab.tests.splice(testIndex, 1);
        await lab.save();

        res.json({
            success: true,
            message: 'Test deleted successfully'
        });

    } catch (error) {
        console.error('Delete test error:', error);
        res.status(500).json({
            success: false,
            message: 'Error deleting test',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// API endpoint to import tests from Excel/CSV
router.post('/api/tests/import', ...testImportUpload, async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({
                success: false,
                message: 'No file uploaded'
            });
        }

        const lab = req.lab;
        const XLSX = require('xlsx');

        // For R2 uploads, we need to get the file buffer or download the file
        // Since testImportUpload uses memory storage, we have the buffer
        const workbook = XLSX.read(req.file.buffer, { type: 'buffer' });
        const sheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[sheetName];

        // Convert to JSON
        const rawData = XLSX.utils.sheet_to_json(worksheet, {
            defval: null,
            raw: false
        });

        // Normalize column names (case-insensitive, trim spaces)
        const normalizedData = rawData.map(row => {
            const keys = Object.keys(row).reduce((acc, key) => {
                const normalizedKey = key.toLowerCase().trim().replace(/\s+/g, '');
                acc[normalizedKey] = row[key];
                return acc;
            }, {});
            return keys;
        });

        // Validate and process tests
        const results = {
            success: [],
            errors: [],
            skipped: []
        };

        const validCategories = [
            'Blood Tests', 'X-Ray', 'MRI', 'CT Scan', 'Ultrasound',
            'Pathology', 'Microbiology', 'Biochemistry', 'Genetics',
            'Allergy', 'Cardiology', 'Neurology', 'General'
        ];

        for (const [index, row] of normalizedData.entries()) {
            const rowNum = index + 2; // Excel row number (1-indexed + header)

            // Extract values with flexible column name matching
            const name = row.name || row.nameen || row.nameenglish || row.testname || row.test;
            const nameAr = row.namear || row.namearabic || row.arabicname || row.arabic || '';
            const price = parseFloat(row.price || row.cost || row.amount);
            const category = row.category || row.cat || row.type;

            // Validation
            if (!name || name.trim() === '') {
                results.errors.push({
                    row: rowNum,
                    message: 'Missing test name'
                });
                continue;
            }

            if (isNaN(price) || price < 0) {
                results.errors.push({
                    row: rowNum,
                    message: 'Invalid price'
                });
                continue;
            }

            // Normalize category - match partial or exact
            let normalizedCategory = 'Blood Tests';
            if (category) {
                const trimmedCategory = category.trim();
                // First try exact match (case-insensitive)
                if (validCategories.some(cat => cat.toLowerCase() === trimmedCategory.toLowerCase())) {
                    normalizedCategory = validCategories.find(cat => cat.toLowerCase() === trimmedCategory.toLowerCase());
                } else {
                    // Try partial match
                    const match = validCategories.find(cat =>
                        cat.toLowerCase().includes(trimmedCategory.toLowerCase()) ||
                        trimmedCategory.toLowerCase().includes(cat.toLowerCase())
                    );
                    if (match) {
                        normalizedCategory = match;
                    }
                }
            }

            // Check if test already exists (by name, case-insensitive)
            const existingTest = lab.tests.find(t =>
                t.name.toLowerCase().trim() === name.toLowerCase().trim()
            );

            if (existingTest) {
                results.skipped.push({
                    row: rowNum,
                    name: name,
                    message: 'Test already exists'
                });
                continue;
            }

            // Generate unique test code
            const testCode = `${normalizedCategory.toUpperCase().replace(/\s+/g, '_')}_${Date.now()}_${index}`;

            // Add test
            const newTest = {
                name: name.trim(),
                nameAr: String(nameAr || '').trim(),
                code: testCode,
                price: Math.round(price),
                category: normalizedCategory,
                description: '',
                instructions: ''
            };

            lab.tests.push(newTest);
            results.success.push({
                row: rowNum,
                name: name,
                price: price,
                category: normalizedCategory
            });
        }

        // Save lab if there are successful additions
        if (results.success.length > 0) {
            await lab.save();
        }

        // File is stored in R2, no local cleanup needed

        res.json({
            success: true,
            message: `Import completed: ${results.success.length} added, ${results.skipped.length} skipped, ${results.errors.length} errors`,
            results: results
        });

    } catch (error) {
        console.error('Test import error:', error);

        // No local file cleanup needed with R2 storage

        res.status(500).json({
            success: false,
            message: 'Error importing tests',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// API endpoint to export tests
router.get('/api/tests/export', async (req, res) => {
    try {
        const lab = req.lab;

        if (!lab.tests || lab.tests.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'No tests to export'
            });
        }

        // Create CSV content
        const csvHeader = 'NameAr,NameEn,Code,Price,Category,Description\n';
        const csvRows = lab.tests.map(test => {
            const nameAr = (test.nameAr || '').replace(/"/g, '""');
            const name = (test.name || '').replace(/"/g, '""');
            const code = (test.code || '').replace(/"/g, '""');
            const price = test.price;
            const category = (test.category || '').replace(/"/g, '""');
            const description = (test.description || '').replace(/"/g, '""');

            return `"${nameAr}","${name}","${code}",${price},"${category}","${description}"`;
        }).join('\n');

        const csvContent = csvHeader + csvRows;

        // Set headers for CSV download
        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename="${lab.name}_tests_${new Date().toISOString().split('T')[0]}.csv"`);
        res.send(csvContent);

    } catch (error) {
        console.error('Export tests error:', error);
        res.status(500).json({
            success: false,
            message: 'Error exporting tests',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get lab test catalog details - view single test from catalog
router.get('/tests/:testId', async (req, res) => {
    try {
        const lab = req.lab;
        const { testId } = req.params;

        // Find the test in the lab's tests catalog
        const test = lab.tests.id(testId) || lab.tests.find(t => t._id.toString() === testId);

        if (!test) {
            return res.status(404).render('error', {
                message: 'Test not found in catalog',
                error: null
            });
        }

        // Get statistics for this test
        const testPatientRequests = lab.patientTests.filter(pt =>
            pt.testId && pt.testId.toString() === test._id.toString()
        );

        const testStats = {
            totalRequests: testPatientRequests.length,
            completedRequests: testPatientRequests.filter(pt => pt.status === 'Completed').length,
            pendingRequests: testPatientRequests.filter(pt => pt.status === 'Pending').length,
            inProgressRequests: testPatientRequests.filter(pt => pt.status === 'In Progress').length,
            averageCompletionTime: testPatientRequests.length > 0 ? '2-3 days' : 'N/A'
        };

        // Get recent patient requests for this test (last 5)
        const recentRequests = testPatientRequests
            .sort((a, b) => new Date(b.requestDate) - new Date(a.requestDate))
            .slice(0, 5);

        // Get patients info for recent requests
        const recentRequestsWithPatients = await Promise.all(
            recentRequests.map(async (req) => {
                const patient = await User.findById(req.patientId).select('name email phone gender birthDate');
                return {
                    ...req.toObject(),
                    patientName: patient ? patient.name : 'Unknown',
                    patientEmail: patient ? patient.email : 'N/A',
                    patientPhone: patient ? patient.phone : 'N/A',
                    patientGender: patient?.gender || null,
                    patientAge: calculateAge(patient?.birthDate)
                };
            })
        );

        // Get language from cookie or default to Arabic
        const currentLang = req.cookies.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = ['ar'].includes(currentLang) ? 'Cairo, sans-serif' : 'Inter, sans-serif';

        res.render('dashboard/lab-test-catalog-details', {
            lab,
            test,
            testStats,
            recentRequests: recentRequestsWithPatients,
            user: req.user,
            title: `Test Details - ${test.name}`,
            currentLang,
            direction,
            font,
            activeSection: 'tests'
        });

    } catch (error) {
        console.error('Test details error:', error);
        res.status(500).render('error', {
            message: 'Error loading test details',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get patient test details - view single patient test request
router.get('/patient-tests/:testId', async (req, res) => {
    try {
        const lab = req.lab;
        const { testId } = req.params;

        // Find the patient test in the lab's patientTests array
        const patientTest = lab.patientTests.id(testId) || lab.patientTests.find(t => t._id.toString() === testId);

        if (!patientTest) {
            return res.status(404).render('error', {
                message: 'Patient test not found',
                error: null
            });
        }

        // Get patient information
        const patient = await User.findById(patientTest.patientId).select('-password');

        // Get language from cookie or default to Arabic
        const currentLang = req.cookies.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = ['ar'].includes(currentLang) ? 'Cairo, sans-serif' : 'Inter, sans-serif';

        // Find the original test details from lab's test catalog
        const testDetails = lab.tests.find(t => t._id.toString() === (patientTest.testId ? patientTest.testId.toString() : ''));

        res.render('dashboard/lab-patient-test-details', {
            lab,
            patientTest,
            patient,
            testDetails,
            user: req.user,
            title: `Patient Test Details - ${patientTest.testName}`,
            currentLang,
            direction,
            font,
            activeSection: 'patient-tests'
        });

    } catch (error) {
        console.error('Patient test details error:', error);
        res.status(500).render('error', {
            message: 'Error loading patient test details',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// API endpoint to update patient test status
router.put('/api/patient-tests/:testId/status', async (req, res) => {
    try {
        const lab = req.lab;
        const { testId } = req.params;
        const { status, notes } = req.body;

        const validStatuses = ['Pending', 'In Progress', 'Completed', 'Cancelled'];
        if (!validStatuses.includes(status)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid status'
            });
        }

        const patientTest = lab.patientTests.id(testId) || lab.patientTests.find(t => t._id.toString() === testId);

        if (!patientTest) {
            return res.status(404).json({
                success: false,
                message: 'Patient test not found'
            });
        }

        // Update status
        patientTest.status = status;

        // Set result date if completed
        if (status === 'Completed') {
            patientTest.resultDate = new Date();
        }

        // Update notes if provided
        if (notes !== undefined) {
            patientTest.notes = notes;
        }

        await lab.save();

        res.json({
            success: true,
            message: 'Test status updated successfully',
            patientTest: patientTest
        });

    } catch (error) {
        console.error('Update test status error:', error);
        res.status(500).json({
            success: false,
            message: 'Error updating test status',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// ==========================================
// ORDER QR SCAN ENDPOINTS FOR LAB
// ==========================================

// Scan QR code to receive sample at lab
router.post('/api/orders/scan-qr', async (req, res) => {
    try {
        const lab = req.lab;
        const labUserId = req.user._id;
        const { qrCode } = req.body;

        if (!qrCode) {
            return res.status(400).json({
                success: false,
                message: 'QR code is required'
            });
        }

        // Find order by QR code
        const order = await Order.findOne({ qrCode: qrCode })
            .populate('patientId', 'name phone gender birthDate patientNo')
            .populate('nurseId', 'name phone');

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Verify order belongs to this lab
        if (order.labId.toString() !== lab._id.toString()) {
            return res.status(403).json({
                success: false,
                message: 'This order does not belong to your lab'
            });
        }

        // Verify order is in sample_collected status (nurse has collected sample)
        if (order.status !== 'sample_collected') {
            return res.status(400).json({
                success: false,
                message: `Cannot receive sample. Order status is: ${order.status}. Expected: sample_collected`
            });
        }

        // Update order status to at_lab
        await order.labReceiveSample(labUserId);

        // Return updated order
        const updatedOrder = await Order.findById(order._id)
            .populate('patientId', 'name phone gender birthDate patientNo')
            .populate('labId', 'name address phone city')
            .populate('nurseId', 'name phone');

        res.json({
            success: true,
            message: 'Sample received successfully',
            data: {
                order: decorateOrderWithPatientInfo(updatedOrder)
            }
        });

    } catch (error) {
        console.error('Lab scan QR code error:', error);
        res.status(500).json({
            success: false,
            message: 'Error scanning QR code',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get orders for this lab (sample_collected - ready for pickup, at_lab - in lab)
router.get('/api/orders', async (req, res) => {
    try {
        const lab = req.lab;
        const { status, page = 1, limit = 20 } = req.query;

        const query = { labId: lab._id };

        if (status) {
            if (status === 'pending_delivery') {
                // Orders where sample is collected and waiting to be delivered
                query.status = 'sample_collected';
            } else if (status === 'in_lab') {
                // Orders where sample is at lab
                query.status = 'at_lab';
            } else if (status === 'active') {
                // All active orders
                query.status = { $in: ['sample_collected', 'at_lab'] };
            } else {
                query.status = status;
            }
        }

        const orders = await Order.find(query)
            .populate('patientId', 'name phone gender birthDate patientNo')
            .populate('nurseId', 'name phone')
            .sort({ createdAt: -1 })
            .limit(parseInt(limit))
            .skip((parseInt(page) - 1) * parseInt(limit))
            .lean();

        const total = await Order.countDocuments(query);

        res.json({
            success: true,
            data: {
                orders: orders.map(order => decorateOrderWithPatientInfo(order)),
                total: total,
                page: parseInt(page),
                pages: Math.ceil(total / parseInt(limit))
            }
        });

    } catch (error) {
        console.error('Get lab orders error:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching orders',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get single order details for lab
router.get('/api/orders/:orderId', async (req, res) => {
    try {
        const lab = req.lab;
        const { orderId } = req.params;

        const order = await Order.findById(orderId)
            .populate('patientId', 'name phone gender birthDate patientNo')
            .populate('nurseId', 'name phone')
            .lean();

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Verify order belongs to this lab
        if (order.labId.toString() !== lab._id.toString()) {
            return res.status(403).json({
                success: false,
                message: 'This order does not belong to your lab'
            });
        }

        res.json({
            success: true,
            data: {
                order: decorateOrderWithPatientInfo(order)
            }
        });

    } catch (error) {
        console.error('Get order details error:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching order details',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Mark order as completed
router.post('/api/orders/:orderId/complete', async (req, res) => {
    try {
        const lab = req.lab;
        const labUserId = req.user._id;
        const { orderId } = req.params;
        const { reportUrl } = req.body;

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Verify order belongs to this lab
        if (order.labId.toString() !== lab._id.toString()) {
            return res.status(403).json({
                success: false,
                message: 'This order does not belong to your lab'
            });
        }

        // Verify order is in at_lab status
        if (order.status !== 'at_lab') {
            return res.status(400).json({
                success: false,
                message: `Cannot complete order. Order status is: ${order.status}. Expected: at_lab`
            });
        }

        // Mark order as completed
        await order.markCompleted(labUserId, reportUrl);

        // Send FCM notification to patient
        try {
            await fcmService.sendToUser(
                order.patientId._id || order.patientId,
                'نتائج الفحوصات جاهزة',
                'نتائج فحوصاتك متاحة الآن',
                {
                    type: 'results_ready',
                    orderId: order._id.toString()
                }
            );
            console.log('FCM: Results ready notification sent to patient');
        } catch (fcmError) {
            console.error('FCM results notification error:', fcmError);
        }

        // Return updated order
        const updatedOrder = await Order.findById(order._id)
            .populate('patientId', 'name phone gender birthDate patientNo')
            .populate('labId', 'name address phone city')
            .populate('nurseId', 'name phone');

        res.json({
            success: true,
            message: 'Order completed successfully',
            data: {
                order: decorateOrderWithPatientInfo(updatedOrder)
            }
        });

    } catch (error) {
        console.error('Complete order error:', error);
        res.status(500).json({
            success: false,
            message: 'Error completing order',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// ==================== OFFERS MANAGEMENT ====================

// Get offers page (dashboard view)
router.get('/offers', async (req, res) => {
    try {
        const lab = req.lab;
        const currentLang = req.cookies?.lang || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = ['ar'].includes(currentLang) ? 'Cairo, sans-serif' : 'Inter, sans-serif';

        // Translation function for this route
        const t = (key) => translateHelper(key, currentLang);

        res.render('dashboard/lab-offers', {
            title: t('offers.title') || 'Offers Management',
            lab,
            offers: lab.offers || [],
            tests: lab.tests || [],
            currentLang,
            direction,
            font,
            t,
            activePage: 'offers'
        });
    } catch (error) {
        console.error('Error loading offers page:', error);
        res.status(500).render('error', {
            message: 'Error loading offers page',
            error: process.env.NODE_ENV === 'development' ? error : {}
        });
    }
});

// Get all offers (API)
router.get('/api/offers', async (req, res) => {
    try {
        const lab = req.lab;
        const { active, testId } = req.query;

        let offers = lab.offers || [];

        // Filter by active status
        if (active === 'true') {
            const now = new Date();
            offers = offers.filter(offer => {
                const isActive = offer.isActive;
                const notExpired = !offer.endDate || new Date(offer.endDate) >= now;
                const hasStarted = new Date(offer.startDate) <= now;
                return isActive && notExpired && hasStarted;
            });
        }

        // Filter by testId
        if (testId) {
            offers = offers.filter(offer => {
                if (offer.applyToAllTests) return true;
                return offer.applicableTests?.some(t => t.testId?.toString() === testId || t.testCode === testId);
            });
        }

        res.json({
            success: true,
            data: {
                offers,
                count: offers.length
            }
        });
    } catch (error) {
        console.error('Error fetching offers:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching offers',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Create a new offer
router.post('/api/offers', async (req, res) => {
    try {
        const lab = req.lab;
        const {
            name,
            nameAr,
            nameKu,
            label,
            labelAr,
            labelKu,
            description,
            descriptionAr,
            descriptionKu,
            discountType,
            discountValue,
            applicableTests,
            applyToAllTests,
            minOrderAmount,
            maxDiscount,
            startDate,
            endDate,
            isActive
        } = req.body;

        // Validate required fields
        if (!name || !discountType || discountValue === undefined) {
            return res.status(400).json({
                success: false,
                message: 'Name, discount type, and discount value are required'
            });
        }

        // Validate discount value
        if (discountType === 'percentage' && (discountValue < 0 || discountValue > 100)) {
            return res.status(400).json({
                success: false,
                message: 'Percentage discount must be between 0 and 100'
            });
        }

        const newOffer = {
            name,
            nameAr: nameAr || name,
            nameKu: nameKu || name,
            label: label || `${discountValue}${discountType === 'percentage' ? '%' : ' IQD'} OFF`,
            labelAr: labelAr || `خصم ${discountValue}${discountType === 'percentage' ? '%' : ' د.ع'}`,
            labelKu: labelKu || `داشکان ${discountValue}${discountType === 'percentage' ? '%' : ' د.ع'}`,
            description,
            descriptionAr,
            descriptionKu,
            discountType,
            discountValue,
            applicableTests: applicableTests || [],
            applyToAllTests: applyToAllTests || false,
            minOrderAmount: minOrderAmount || 0,
            maxDiscount: maxDiscount || 0,
            startDate: startDate || new Date(),
            endDate: endDate || null,
            isActive: isActive !== undefined ? isActive : true,
            createdAt: new Date()
        };

        lab.offers = lab.offers || [];
        lab.offers.push(newOffer);
        await lab.save();

        const createdOffer = lab.offers[lab.offers.length - 1];

        // Send FCM notification to patients in this lab's own governorate -
        // a patient elsewhere can't even see/use this lab, so 'all_patients'
        // was spamming everyone with offers that don't concern them.
        try {
            const offerLabel = createdOffer.label || createdOffer.name || 'عرض خاص';
            const topic = `patient_city_${cityToTopicKey(lab.city)}`;
            await fcmService.sendToTopic(
                topic,
                'عرض جديد!',
                `${lab.name}: ${offerLabel}`,
                {
                    type: 'lab_offer',
                    labId: lab._id.toString(),
                    offerId: createdOffer._id.toString(),
                    labName: lab.name
                }
            );
            console.log(`FCM: Offer notification sent to ${topic}`);
        } catch (fcmError) {
            console.error('FCM offer notification error:', fcmError);
            // Don't fail the request if notification fails
        }

        res.status(201).json({
            success: true,
            message: 'Offer created successfully',
            data: {
                offer: createdOffer
            }
        });
    } catch (error) {
        console.error('Error creating offer:', error);
        res.status(500).json({
            success: false,
            message: 'Error creating offer',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get single offer
router.get('/api/offers/:offerId', async (req, res) => {
    try {
        const lab = req.lab;
        const { offerId } = req.params;

        const offer = lab.offers?.id(offerId);

        if (!offer) {
            return res.status(404).json({
                success: false,
                message: 'Offer not found'
            });
        }

        res.json({
            success: true,
            data: {
                offer
            }
        });
    } catch (error) {
        console.error('Error fetching offer:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching offer',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Update an offer
router.put('/api/offers/:offerId', async (req, res) => {
    try {
        const lab = req.lab;
        const { offerId } = req.params;
        const updates = req.body;

        const offer = lab.offers?.id(offerId);

        if (!offer) {
            return res.status(404).json({
                success: false,
                message: 'Offer not found'
            });
        }

        // Update fields
        const allowedUpdates = [
            'name', 'nameAr', 'nameKu',
            'label', 'labelAr', 'labelKu',
            'description', 'descriptionAr', 'descriptionKu',
            'discountType', 'discountValue',
            'applicableTests', 'applyToAllTests',
            'minOrderAmount', 'maxDiscount',
            'startDate', 'endDate', 'isActive'
        ];

        allowedUpdates.forEach(field => {
            if (updates[field] !== undefined) {
                offer[field] = updates[field];
            }
        });

        await lab.save();

        res.json({
            success: true,
            message: 'Offer updated successfully',
            data: {
                offer
            }
        });
    } catch (error) {
        console.error('Error updating offer:', error);
        res.status(500).json({
            success: false,
            message: 'Error updating offer',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Delete an offer
router.delete('/api/offers/:offerId', async (req, res) => {
    try {
        const lab = req.lab;
        const { offerId } = req.params;

        const offer = lab.offers?.id(offerId);

        if (!offer) {
            return res.status(404).json({
                success: false,
                message: 'Offer not found'
            });
        }

        // Use pull to remove the subdocument
        lab.offers.pull(offerId);
        await lab.save();

        res.json({
            success: true,
            message: 'Offer deleted successfully'
        });
    } catch (error) {
        console.error('Error deleting offer:', error);
        res.status(500).json({
            success: false,
            message: 'Error deleting offer',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Toggle offer active status
router.patch('/api/offers/:offerId/toggle', async (req, res) => {
    try {
        const lab = req.lab;
        const { offerId } = req.params;

        const offer = lab.offers?.id(offerId);

        if (!offer) {
            return res.status(404).json({
                success: false,
                message: 'Offer not found'
            });
        }

        offer.isActive = !offer.isActive;
        await lab.save();

        res.json({
            success: true,
            message: `Offer ${offer.isActive ? 'activated' : 'deactivated'} successfully`,
            data: {
                offer
            }
        });
    } catch (error) {
        console.error('Error toggling offer:', error);
        res.status(500).json({
            success: false,
            message: 'Error toggling offer status',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// ==================== PACKAGES MANAGEMENT ====================
// Packages are a top-level collection (not embedded on Lab, unlike offers)
// so the public browse screen can search/filter/paginate across every
// lab's packages with a real index instead of aggregating an embedded array.

// Get packages page (dashboard view)
router.get('/packages', async (req, res) => {
    try {
        const lab = req.lab;
        const currentLang = req.cookies?.lang || 'ar';
        const direction = ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr';
        const font = ['ar'].includes(currentLang) ? 'Cairo, sans-serif' : 'Inter, sans-serif';
        const t = (key) => translateHelper(key, currentLang);

        const packages = await Package.find({ labId: lab._id }).sort({ createdAt: -1 });

        res.render('dashboard/lab-packages', {
            title: t('packages.title') || 'Packages Management',
            lab,
            packages,
            tests: lab.tests || [],
            currentLang,
            direction,
            font,
            t,
            activePage: 'packages'
        });
    } catch (error) {
        console.error('Error loading packages page:', error);
        res.status(500).render('error', {
            message: 'Error loading packages page',
            error: process.env.NODE_ENV === 'development' ? error : {}
        });
    }
});

// Get all of this lab's packages (API)
router.get('/api/packages', async (req, res) => {
    try {
        const lab = req.lab;
        const packages = await Package.find({ labId: lab._id }).sort({ createdAt: -1 });

        res.json({
            success: true,
            data: { packages, count: packages.length }
        });
    } catch (error) {
        console.error('Error fetching packages:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching packages',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Create a new package
router.post('/api/packages', async (req, res) => {
    try {
        const lab = req.lab;
        const {
            name, nameAr, nameKu,
            description, descriptionAr, descriptionKu,
            category, testIds, price, icon,
            isMostRequested, isActive
        } = req.body;

        if (!name || !Array.isArray(testIds) || testIds.length < 2 || price === undefined) {
            return res.status(400).json({
                success: false,
                message: 'Name, at least 2 tests, and price are required'
            });
        }

        // Every testId must belong to this lab's own tests.
        const labTestIds = new Set(lab.tests.map(t => t._id.toString()));
        const invalidId = testIds.find(id => !labTestIds.has(String(id)));
        if (invalidId) {
            return res.status(400).json({
                success: false,
                message: 'One or more selected tests do not belong to this lab'
            });
        }

        const newPackage = await Package.create({
            labId: lab._id,
            name,
            nameAr: nameAr || name,
            nameKu: nameKu || name,
            description, descriptionAr, descriptionKu,
            category: category || 'General',
            testIds,
            price: Math.round(parseFloat(price)),
            icon: icon || null,
            isMostRequested: isMostRequested || false,
            isActive: isActive !== undefined ? isActive : true,
        });

        res.status(201).json({
            success: true,
            message: 'Package created successfully',
            data: { package: newPackage }
        });
    } catch (error) {
        console.error('Error creating package:', error);
        res.status(500).json({
            success: false,
            message: 'Error creating package',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Get a single package (scoped to this lab)
router.get('/api/packages/:id', async (req, res) => {
    try {
        const lab = req.lab;
        const pkg = await Package.findOne({ _id: req.params.id, labId: lab._id });

        if (!pkg) {
            return res.status(404).json({ success: false, message: 'Package not found' });
        }

        res.json({ success: true, data: { package: pkg } });
    } catch (error) {
        console.error('Error fetching package:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching package',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Update a package
router.put('/api/packages/:id', async (req, res) => {
    try {
        const lab = req.lab;
        const pkg = await Package.findOne({ _id: req.params.id, labId: lab._id });

        if (!pkg) {
            return res.status(404).json({ success: false, message: 'Package not found' });
        }

        const updates = req.body;

        if (updates.testIds !== undefined) {
            if (!Array.isArray(updates.testIds) || updates.testIds.length < 2) {
                return res.status(400).json({ success: false, message: 'A package needs at least 2 tests' });
            }
            const labTestIds = new Set(lab.tests.map(t => t._id.toString()));
            const invalidId = updates.testIds.find(id => !labTestIds.has(String(id)));
            if (invalidId) {
                return res.status(400).json({
                    success: false,
                    message: 'One or more selected tests do not belong to this lab'
                });
            }
        }

        const allowedUpdates = [
            'name', 'nameAr', 'nameKu',
            'description', 'descriptionAr', 'descriptionKu',
            'category', 'testIds', 'price', 'icon',
            'isMostRequested', 'isActive'
        ];

        allowedUpdates.forEach(field => {
            if (updates[field] !== undefined) {
                pkg[field] = field === 'price' ? Math.round(parseFloat(updates[field])) : updates[field];
            }
        });

        await pkg.save();

        res.json({ success: true, message: 'Package updated successfully', data: { package: pkg } });
    } catch (error) {
        console.error('Error updating package:', error);
        res.status(500).json({
            success: false,
            message: 'Error updating package',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Delete a package
router.delete('/api/packages/:id', async (req, res) => {
    try {
        const lab = req.lab;
        const result = await Package.deleteOne({ _id: req.params.id, labId: lab._id });

        if (result.deletedCount === 0) {
            return res.status(404).json({ success: false, message: 'Package not found' });
        }

        res.json({ success: true, message: 'Package deleted successfully' });
    } catch (error) {
        console.error('Error deleting package:', error);
        res.status(500).json({
            success: false,
            message: 'Error deleting package',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

// Toggle package active status
router.patch('/api/packages/:id/toggle', async (req, res) => {
    try {
        const lab = req.lab;
        const pkg = await Package.findOne({ _id: req.params.id, labId: lab._id });

        if (!pkg) {
            return res.status(404).json({ success: false, message: 'Package not found' });
        }

        pkg.isActive = !pkg.isActive;
        await pkg.save();

        res.json({
            success: true,
            message: `Package ${pkg.isActive ? 'activated' : 'deactivated'} successfully`,
            data: { package: pkg }
        });
    } catch (error) {
        console.error('Error toggling package:', error);
        res.status(500).json({
            success: false,
            message: 'Error toggling package status',
            error: process.env.NODE_ENV === 'development' ? error.message : null
        });
    }
});

module.exports = router;
module.exports.cleanLicenseHolders = cleanLicenseHolders;
