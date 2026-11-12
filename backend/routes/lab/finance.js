const express = require('express');
const router = express.Router();
const Order = require('../../models/Order');
const Transaction = require('../../models/Transaction');
const { verifyToken } = require('../../middleware/auth');

// @route   GET /api/lab/finance/overview
// @desc    Get lab finance overview
// @access  Private (Lab)
router.get('/overview', verifyToken, async (req, res) => {
    try {
        // Verify user is a lab
        if (req.user.role !== 'lab') {
            return res.status(403).json({
                success: false,
                message: 'Access denied. Labs only.'
            });
        }

        // Get lab's orders with financials
        const orders = await Order.find({
            labId: req.user.labId,
            'financials.labAmount': { $gt: 0 }
        });

        // Calculate totals
        const totalOrders = orders.length;
        const completedOrders = orders.filter(o => o.status === 'completed').length;
        const totalRevenue = orders.reduce((sum, o) => sum + (o.financials?.labAmount || 0), 0);
        const settledAmount = orders
            .filter(o => o.financials?.labSettled)
            .reduce((sum, o) => sum + (o.financials?.labAmount || 0), 0);
        const pendingAmount = totalRevenue - settledAmount;

        // This month stats
        const startOfMonth = new Date();
        startOfMonth.setDate(1);
        startOfMonth.setHours(0, 0, 0, 0);

        const thisMonthOrders = orders.filter(o => new Date(o.createdAt) >= startOfMonth);
        const thisMonthRevenue = thisMonthOrders.reduce((sum, o) => sum + (o.financials?.labAmount || 0), 0);

        // Commission paid (to admin via nurses)
        const totalCommission = orders.reduce((sum, o) => sum + (o.financials?.adminCommission || 0), 0);

        res.json({
            success: true,
            data: {
                overview: {
                    totalOrders,
                    completedOrders,
                    totalRevenue,
                    settledAmount,
                    pendingAmount,
                    totalCommission
                },
                thisMonth: {
                    orders: thisMonthOrders.length,
                    revenue: thisMonthRevenue
                }
            }
        });
    } catch (error) {
        console.error('Lab finance overview error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// @route   GET /api/lab/finance/transactions
// @desc    Get lab transaction history
// @access  Private (Lab)
router.get('/transactions', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'lab') {
            return res.status(403).json({
                success: false,
                message: 'Access denied. Labs only.'
            });
        }

        const { page = 1, limit = 20 } = req.query;
        const skip = (parseInt(page) - 1) * parseInt(limit);

        const transactions = await Transaction.find({
            labId: req.user.labId
        })
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(parseInt(limit))
            .populate('orderId', 'qrCode pricing')
            .populate('nurseId', 'name');

        const total = await Transaction.countDocuments({ labId: req.user.labId });

        res.json({
            success: true,
            data: {
                transactions,
                total,
                page: parseInt(page),
                pages: Math.ceil(total / parseInt(limit))
            }
        });
    } catch (error) {
        console.error('Lab transactions error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// @route   GET /api/lab/finance/orders
// @desc    Get lab orders with financial details
// @access  Private (Lab)
router.get('/orders', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'lab') {
            return res.status(403).json({
                success: false,
                message: 'Access denied. Labs only.'
            });
        }

        const { 
            page = 1, 
            limit = 20,
            settled // 'true', 'false', or undefined for all
        } = req.query;

        const skip = (parseInt(page) - 1) * parseInt(limit);

        const query = {
            labId: req.user.labId,
            'financials.labAmount': { $gt: 0 }
        };

        if (settled === 'true') {
            query['financials.labSettled'] = true;
        } else if (settled === 'false') {
            query['financials.labSettled'] = { $ne: true };
        }

        const orders = await Order.find(query)
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(parseInt(limit))
            .populate('nurseId', 'name phone')
            .populate('patientId', 'name');

        const total = await Order.countDocuments(query);

        res.json({
            success: true,
            data: {
                orders: orders.map(o => ({
                    _id: o._id,
                    orderNumber: o.qrCode,
                    patient: o.patientId?.name || 'Unknown',
                    nurse: o.nurseId?.name || 'Unassigned',
                    nursePhone: o.nurseId?.phone,
                    totalAmount: o.pricing?.total || 0,
                    labAmount: o.financials?.labAmount || 0,
                    commissionRate: o.financials?.commissionRate || 0,
                    adminCommission: o.financials?.adminCommission || 0,
                    labSettled: o.financials?.labSettled || false,
                    labSettledAt: o.financials?.labSettledAt,
                    status: o.status,
                    createdAt: o.createdAt
                })),
                total,
                page: parseInt(page),
                pages: Math.ceil(total / parseInt(limit))
            }
        });
    } catch (error) {
        console.error('Lab orders error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// @route   GET /api/lab/finance/earnings-report
// @desc    Get monthly earnings report
// @access  Private (Lab)
router.get('/earnings-report', verifyToken, async (req, res) => {
    try {
        if (req.user.role !== 'lab') {
            return res.status(403).json({
                success: false,
                message: 'Access denied. Labs only.'
            });
        }

        const { months = 6 } = req.query;
        const startDate = new Date();
        startDate.setMonth(startDate.getMonth() - parseInt(months));
        startDate.setDate(1);
        startDate.setHours(0, 0, 0, 0);

        const orders = await Order.aggregate([
            {
                $match: {
                    labId: req.user.labId,
                    'financials.labAmount': { $gt: 0 },
                    createdAt: { $gte: startDate }
                }
            },
            {
                $group: {
                    _id: {
                        year: { $year: '$createdAt' },
                        month: { $month: '$createdAt' }
                    },
                    orders: { $sum: 1 },
                    revenue: { $sum: '$financials.labAmount' },
                    commission: { $sum: '$financials.adminCommission' }
                }
            },
            {
                $sort: { '_id.year': 1, '_id.month': 1 }
            }
        ]);

        // Format the data
        const report = orders.map(item => ({
            month: `${item._id.year}-${String(item._id.month).padStart(2, '0')}`,
            orders: item.orders,
            revenue: item.revenue,
            commission: item.commission
        }));

        // Calculate totals
        const totals = report.reduce(
            (acc, month) => ({
                orders: acc.orders + month.orders,
                revenue: acc.revenue + month.revenue,
                commission: acc.commission + month.commission
            }),
            { orders: 0, revenue: 0, commission: 0 }
        );

        res.json({
            success: true,
            data: {
                report,
                totals
            }
        });
    } catch (error) {
        console.error('Lab earnings report error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

module.exports = router;
