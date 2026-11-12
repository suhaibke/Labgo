const express = require('express');
const router = express.Router();
const Order = require('../../models/Order');
const User = require('../../models/User');
const Lab = require('../../models/Lab');
const Transaction = require('../../models/Transaction');
const { verifyToken } = require('../../middleware/auth');

// Nurse role verification middleware
const nurseOnly = async (req, res, next) => {
    if (req.userRole !== 'nurse') {
        return res.status(403).json({
            success: false,
            message: 'Access denied. Nurse role required.'
        });
    }
    next();
};

// ==================== NURSE FINANCIAL DASHBOARD ====================

/**
 * GET /api/nurse/finance/overview
 * Get nurse's financial overview (for Flutter app)
 */
router.get('/overview', verifyToken, nurseOnly, async (req, res) => {
    try {
        const nurseId = req.user.id;

        const nurse = await User.findById(nurseId)
            .select('name nurseBalance totalEarnings totalPaidToAdmin lastSettlementDate nurseCommissionRate');

        // Get today's stats
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);

        const todayStats = await Order.aggregate([
            {
                $match: {
                    nurseId: nurse._id,
                    'paymentCollected.collected': true,
                    'paymentCollected.collectedAt': { $gte: today, $lt: tomorrow },
                }
            },
            {
                $group: {
                    _id: null,
                    totalCollected: { $sum: '$pricing.total' },
                    orderCount: { $sum: 1 },
                    adminAmount: { $sum: '$financials.adminAmount' },
                    nurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                    totalLabAmount: { $sum: '$financials.labAmount' },
                }
            }
        ]);

        // Get this week's stats
        const weekStart = new Date(today);
        weekStart.setDate(weekStart.getDate() - weekStart.getDay());
        
        const weekStats = await Order.aggregate([
            {
                $match: {
                    nurseId: nurse._id,
                    'paymentCollected.collected': true,
                    'paymentCollected.collectedAt': { $gte: weekStart },
                }
            },
            {
                $group: {
                    _id: null,
                    totalCollected: { $sum: '$pricing.total' },
                    orderCount: { $sum: 1 },
                    adminAmount: { $sum: '$financials.adminAmount' },
                    nurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                    totalLabAmount: { $sum: '$financials.labAmount' },
                }
            }
        ]);

        // Get this month's stats
        const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
        
        const monthStats = await Order.aggregate([
            {
                $match: {
                    nurseId: nurse._id,
                    'paymentCollected.collected': true,
                    'paymentCollected.collectedAt': { $gte: monthStart },
                }
            },
            {
                $group: {
                    _id: null,
                    totalCollected: { $sum: '$pricing.total' },
                    orderCount: { $sum: 1 },
                    adminAmount: { $sum: '$financials.adminAmount' },
                    nurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                    totalLabAmount: { $sum: '$financials.labAmount' },
                }
            }
        ]);

        // Get pending lab settlements (orders collected but not settled with lab)
        const pendingLabSettlements = await Order.find({
            nurseId,
            'paymentCollected.collected': true,
            'financials.labSettled': false,
            status: { $in: ['sample_collected', 'at_lab', 'completed'] },
        })
        .populate('labId', 'name')
        .select('qrCode pricing.total financials labId createdAt');

        const totalPendingLabAmount = pendingLabSettlements.reduce(
            (sum, order) => sum + (order.financials?.labAmount || 0), 0
        );

        // Get pending admin settlements (what nurse owes admin)
        const pendingAdminSettlements = await Order.find({
            nurseId,
            'paymentCollected.collected': true,
            'financials.adminSettled': false,
            status: { $in: ['sample_collected', 'at_lab', 'completed'] },
        })
        .populate('labId', 'name')
        .select('qrCode pricing.total financials labId createdAt');

        const totalPendingAdminAmount = pendingAdminSettlements.reduce(
            (sum, order) => sum + (order.financials?.adminAmount || 0), 0
        );

        res.json({
            success: true,
            data: {
                nurse: {
                    name: nurse.name,
                    currentBalance: nurse.nurseBalance, // What nurse owes admin
                    totalEarnings: nurse.totalEarnings, // Nurse's net profit
                    totalPaidToAdmin: nurse.totalPaidToAdmin,
                    lastSettlementDate: nurse.lastSettlementDate,
                    commissionRate: nurse.nurseCommissionRate,
                },
                today: {
                    totalCollected: todayStats[0]?.totalCollected || 0,
                    orderCount: todayStats[0]?.orderCount || 0,
                    adminAmount: todayStats[0]?.adminAmount || 0,
                    nurseNetEarning: todayStats[0]?.nurseNetEarning || 0,
                    labAmountDue: todayStats[0]?.totalLabAmount || 0,
                },
                thisWeek: {
                    totalCollected: weekStats[0]?.totalCollected || 0,
                    orderCount: weekStats[0]?.orderCount || 0,
                    adminAmount: weekStats[0]?.adminAmount || 0,
                    nurseNetEarning: weekStats[0]?.nurseNetEarning || 0,
                    labAmountDue: weekStats[0]?.totalLabAmount || 0,
                },
                thisMonth: {
                    totalCollected: monthStats[0]?.totalCollected || 0,
                    orderCount: monthStats[0]?.orderCount || 0,
                    adminAmount: monthStats[0]?.adminAmount || 0,
                    nurseNetEarning: monthStats[0]?.nurseNetEarning || 0,
                    labAmountDue: monthStats[0]?.totalLabAmount || 0,
                },
                pendingLabSettlements: {
                    totalAmount: totalPendingLabAmount,
                    orders: pendingLabSettlements,
                },
                pendingAdminSettlements: {
                    totalAmount: totalPendingAdminAmount,
                    orders: pendingAdminSettlements,
                },
            }
        });
    } catch (error) {
        console.error('Error fetching nurse finance overview:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch financial overview' });
    }
});

/**
 * GET /api/nurse/finance/order/:orderId
 * Get financial breakdown for a specific order
 */
router.get('/order/:orderId', verifyToken, nurseOnly, async (req, res) => {
    try {
        const { orderId } = req.params;
        const nurseId = req.user.id;

        const order = await Order.findOne({ _id: orderId, nurseId })
            .populate('labId', 'name commissionRate')
            .populate('patientId', 'name phone');

        if (!order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        res.json({
            success: true,
            data: {
                order: {
                    id: order._id,
                    qrCode: order.qrCode,
                    status: order.status,
                    patient: order.patientId,
                    lab: order.labId,
                },
                pricing: order.pricing,
                financials: {
                    totalAmount: order.pricing.total,
                    labCommissionRate: order.financials?.labCommissionRate || 0,
                    nurseCommissionRate: order.financials?.nurseCommissionRate || 0,
                    labAmount: order.financials?.labAmount || 0,
                    nurseEarningBeforeAdmin: order.financials?.nurseEarningBeforeAdmin || 0,
                    adminAmount: order.financials?.adminAmount || 0,
                    nurseNetEarning: order.financials?.nurseNetEarning || 0,
                    labSettled: order.financials?.labSettled || false,
                    labSettledAt: order.financials?.labSettledAt,
                    adminSettled: order.financials?.adminSettled || false,
                    adminSettledAt: order.financials?.adminSettledAt,
                },
                paymentCollected: order.paymentCollected,
            }
        });
    } catch (error) {
        console.error('Error fetching order financials:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch order financials' });
    }
});

/**
 * GET /api/nurse/finance/transactions
 * Get nurse's transaction history
 */
router.get('/transactions', verifyToken, nurseOnly, async (req, res) => {
    try {
        const nurseId = req.user.id;
        const { page = 1, limit = 20, type } = req.query;
        const skip = (page - 1) * limit;

        const query = { nurseId };
        if (type) query.type = type;

        const transactions = await Transaction.find(query)
            .populate('labId', 'name')
            .populate('orderId', 'qrCode')
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(parseInt(limit));

        const total = await Transaction.countDocuments(query);

        res.json({
            success: true,
            data: {
                transactions,
                total,
                page: parseInt(page),
                pages: Math.ceil(total / limit),
            }
        });
    } catch (error) {
        console.error('Error fetching transactions:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch transactions' });
    }
});

/**
 * GET /api/nurse/finance/pending-settlements
 * Get orders pending lab settlement
 */
router.get('/pending-settlements', verifyToken, nurseOnly, async (req, res) => {
    try {
        const nurseId = req.user.id;

        const pendingOrders = await Order.find({
            nurseId,
            'paymentCollected.collected': true,
            'financials.labSettled': false,
            status: { $in: ['sample_collected', 'at_lab', 'completed'] },
        })
        .populate('labId', 'name phone address')
        .populate('patientId', 'name')
        .sort({ createdAt: -1 });

        // Group by lab
        const byLab = {};
        for (const order of pendingOrders) {
            const labId = order.labId._id.toString();
            if (!byLab[labId]) {
                byLab[labId] = {
                    lab: order.labId,
                    orders: [],
                    totalAmount: 0,
                };
            }
            byLab[labId].orders.push(order);
            byLab[labId].totalAmount += order.financials?.labAmount || 0;
        }

        res.json({
            success: true,
            data: {
                pendingByLab: Object.values(byLab),
                totalPendingAmount: pendingOrders.reduce(
                    (sum, o) => sum + (o.financials?.labAmount || 0), 0
                ),
                totalOrders: pendingOrders.length,
            }
        });
    } catch (error) {
        console.error('Error fetching pending settlements:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch pending settlements' });
    }
});

/**
 * POST /api/nurse/finance/settle-lab/:orderId
 * Mark order as settled with lab (nurse paid lab)
 */
router.post('/settle-lab/:orderId', verifyToken, nurseOnly, async (req, res) => {
    try {
        const { orderId } = req.params;
        const nurseId = req.user.id;

        const order = await Order.findOne({ _id: orderId, nurseId });

        if (!order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        if (!order.paymentCollected?.collected) {
            return res.status(400).json({ success: false, message: 'Payment not yet collected from patient' });
        }

        if (order.financials?.labSettled) {
            return res.status(400).json({ success: false, message: 'Order already settled with lab' });
        }

        // Mark as settled
        order.financials.labSettled = true;
        order.financials.labSettledAt = new Date();
        order.financials.labSettledBy = nurseId;
        await order.save();

        // Create transaction record
        const transaction = new Transaction({
            type: 'lab_settlement',
            amount: order.financials.labAmount,
            orderId: order._id,
            labId: order.labId,
            nurseId: nurseId,
            description: `Lab settlement for order ${order.qrCode}`,
            referenceNumber: Transaction.generateReferenceNumber('lab_settlement'),
        });
        await transaction.save();

        res.json({
            success: true,
            message: 'Order marked as settled with lab',
            data: {
                order: {
                    id: order._id,
                    qrCode: order.qrCode,
                    labAmount: order.financials.labAmount,
                    settledAt: order.financials.labSettledAt,
                },
                transaction,
            }
        });
    } catch (error) {
        console.error('Error settling with lab:', error);
        res.status(500).json({ success: false, message: 'Failed to settle with lab' });
    }
});

/**
 * POST /api/nurse/finance/settle-lab-batch
 * Batch settle multiple orders with a lab
 */
router.post('/settle-lab-batch', verifyToken, nurseOnly, async (req, res) => {
    try {
        const nurseId = req.user.id;
        const { orderIds } = req.body;

        if (!orderIds || !Array.isArray(orderIds) || orderIds.length === 0) {
            return res.status(400).json({ success: false, message: 'Order IDs are required' });
        }

        const orders = await Order.find({
            _id: { $in: orderIds },
            nurseId,
            'paymentCollected.collected': true,
            'financials.labSettled': false,
        });

        if (orders.length === 0) {
            return res.status(400).json({ success: false, message: 'No valid orders found to settle' });
        }

        let totalSettled = 0;
        const settledOrders = [];

        for (const order of orders) {
            order.financials.labSettled = true;
            order.financials.labSettledAt = new Date();
            order.financials.labSettledBy = nurseId;
            await order.save();

            // Create transaction
            const transaction = new Transaction({
                type: 'lab_settlement',
                amount: order.financials.labAmount,
                orderId: order._id,
                labId: order.labId,
                nurseId: nurseId,
                description: `Lab settlement for order ${order.qrCode}`,
                referenceNumber: Transaction.generateReferenceNumber('lab_settlement'),
            });
            await transaction.save();

            totalSettled += order.financials.labAmount;
            settledOrders.push({
                orderId: order._id,
                qrCode: order.qrCode,
                amount: order.financials.labAmount,
            });
        }

        res.json({
            success: true,
            message: `Successfully settled ${orders.length} orders`,
            data: {
                totalSettled,
                settledOrders,
            }
        });
    } catch (error) {
        console.error('Error batch settling with lab:', error);
        res.status(500).json({ success: false, message: 'Failed to batch settle with lab' });
    }
});

/**
 * GET /api/nurse/finance/earnings-history
 * Get historical earnings breakdown by month
 */
router.get('/earnings-history', verifyToken, nurseOnly, async (req, res) => {
    try {
        const nurseId = req.user.id;
        const { months = 6 } = req.query;

        const startDate = new Date();
        startDate.setMonth(startDate.getMonth() - parseInt(months));

        const monthlyEarnings = await Order.aggregate([
            {
                $match: {
                    nurseId: new (require('mongoose').Types.ObjectId)(nurseId),
                    'paymentCollected.collected': true,
                    'paymentCollected.collectedAt': { $gte: startDate },
                }
            },
            {
                $group: {
                    _id: {
                        year: { $year: '$paymentCollected.collectedAt' },
                        month: { $month: '$paymentCollected.collectedAt' },
                    },
                    totalCollected: { $sum: '$pricing.total' },
                    orderCount: { $sum: 1 },
                    adminAmount: { $sum: '$financials.adminAmount' },
                    nurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                    totalLabAmount: { $sum: '$financials.labAmount' },
                }
            },
            { $sort: { '_id.year': -1, '_id.month': -1 } }
        ]);

        res.json({
            success: true,
            data: {
                monthlyEarnings,
            }
        });
    } catch (error) {
        console.error('Error fetching earnings history:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch earnings history' });
    }
});

/**
 * GET /api/nurse/finance/monthly/:year/:month
 * Get finance data for a specific month
 */
router.get('/monthly/:year/:month', verifyToken, nurseOnly, async (req, res) => {
    try {
        const nurseId = req.user.id;
        const { year, month } = req.params;
        
        const startDate = new Date(parseInt(year), parseInt(month) - 1, 1);
        const endDate = new Date(parseInt(year), parseInt(month), 0, 23, 59, 59, 999);

        const nurse = await User.findById(nurseId)
            .select('name nurseBalance totalEarnings totalPaidToAdmin lastSettlementDate nurseCommissionRate');

        // Get month's stats
        const monthStats = await Order.aggregate([
            {
                $match: {
                    nurseId: nurse._id,
                    'paymentCollected.collected': true,
                    'paymentCollected.collectedAt': { $gte: startDate, $lte: endDate },
                }
            },
            {
                $group: {
                    _id: null,
                    totalCollected: { $sum: '$pricing.total' },
                    orderCount: { $sum: 1 },
                    adminAmount: { $sum: '$financials.adminAmount' },
                    nurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                    totalLabAmount: { $sum: '$financials.labAmount' },
                }
            }
        ]);

        // Get transactions for this month
        const transactions = await Transaction.find({
            nurseId: nurse._id,
            createdAt: { $gte: startDate, $lte: endDate },
        })
        .populate('labId', 'name')
        .sort({ createdAt: -1 });

        // Get orders for this month
        const orders = await Order.find({
            nurseId: nurse._id,
            'paymentCollected.collected': true,
            'paymentCollected.collectedAt': { $gte: startDate, $lte: endDate },
        })
        .populate('labId', 'name')
        .select('qrCode pricing.total financials labId createdAt status paymentCollected')
        .sort({ 'paymentCollected.collectedAt': -1 });

        res.json({
            success: true,
            data: {
                year: parseInt(year),
                month: parseInt(month),
                stats: {
                    totalCollected: monthStats[0]?.totalCollected || 0,
                    orderCount: monthStats[0]?.orderCount || 0,
                    adminAmount: monthStats[0]?.adminAmount || 0,
                    nurseNetEarning: monthStats[0]?.nurseNetEarning || 0,
                    labAmountDue: monthStats[0]?.totalLabAmount || 0,
                },
                transactions,
                orders,
            }
        });
    } catch (error) {
        console.error('Error fetching monthly data:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch monthly data' });
    }
});

/**
 * GET /api/nurse/finance/available-months
 * Get list of months with data
 */
router.get('/available-months', verifyToken, nurseOnly, async (req, res) => {
    try {
        const nurseId = req.user.id;

        const months = await Order.aggregate([
            {
                $match: {
                    nurseId: new (require('mongoose').Types.ObjectId)(nurseId),
                    'paymentCollected.collected': true,
                }
            },
            {
                $group: {
                    _id: {
                        year: { $year: '$paymentCollected.collectedAt' },
                        month: { $month: '$paymentCollected.collectedAt' },
                    },
                    orderCount: { $sum: 1 },
                    totalEarning: { $sum: '$financials.nurseNetEarning' },
                }
            },
            { $sort: { '_id.year': -1, '_id.month': -1 } },
            { $limit: 24 }
        ]);

        res.json({
            success: true,
            data: {
                months: months.map(m => ({
                    year: m._id.year,
                    month: m._id.month,
                    orderCount: m.orderCount,
                    totalEarning: m.totalEarning,
                })),
            }
        });
    } catch (error) {
        console.error('Error fetching available months:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch available months' });
    }
});

module.exports = router;
