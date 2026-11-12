const express = require('express');
const router = express.Router();
const Order = require('../../models/Order');
const User = require('../../models/User');
const Lab = require('../../models/Lab');
const Transaction = require('../../models/Transaction');
const { verifyToken } = require('../../middleware/auth');

// Admin role verification middleware
const adminOnly = async (req, res, next) => {
    if (req.userRole !== 'admin') {
        return res.status(403).json({
            success: false,
            message: 'Access denied. Admin role required.'
        });
    }
    next();
};

// ==================== DASHBOARD OVERVIEW ====================

/**
 * GET /api/admin/finance/overview
 * Get overall financial dashboard overview
 */
router.get('/overview', verifyToken, adminOnly, async (req, res) => {
    try {
        const { startDate, endDate } = req.query;
        
        // Build date filter
        const dateFilter = {};
        if (startDate) dateFilter.$gte = new Date(startDate);
        if (endDate) dateFilter.$lte = new Date(endDate);
        
        const orderQuery = {};
        if (startDate || endDate) {
            orderQuery.createdAt = dateFilter;
        }

        // Get total orders revenue
        const ordersStats = await Order.aggregate([
            { $match: { ...orderQuery, status: { $nin: ['cancelled'] } } },
            {
                $group: {
                    _id: null,
                    totalRevenue: { $sum: '$pricing.total' },
                    totalAdminAmount: { $sum: '$financials.adminAmount' },
                    totalLabAmount: { $sum: '$financials.labAmount' },
                    totalNurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                    orderCount: { $sum: 1 },
                    completedOrders: {
                        $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] }
                    },
                }
            }
        ]);

        // Get total nurse balances (money owed to admin)
        const nurseBalances = await User.aggregate([
            { $match: { role: 'nurse' } },
            {
                $group: {
                    _id: null,
                    totalBalance: { $sum: '$nurseBalance' },
                    totalEarnings: { $sum: '$totalEarnings' },
                    totalPaidToAdmin: { $sum: '$totalPaidToAdmin' },
                    nurseCount: { $sum: 1 },
                }
            }
        ]);

        // Get pending lab settlements (unsettled lab payments)
        const pendingLabSettlements = await Order.aggregate([
            {
                $match: {
                    'financials.labSettled': false,
                    'paymentCollected.collected': true,
                    status: { $in: ['sample_collected', 'at_lab', 'completed'] },
                }
            },
            {
                $group: {
                    _id: null,
                    pendingAmount: { $sum: '$financials.labAmount' },
                    orderCount: { $sum: 1 },
                }
            }
        ]);

        // Get pending admin settlements (what nurses owe admin)
        const pendingAdminSettlements = await Order.aggregate([
            {
                $match: {
                    'financials.adminSettled': false,
                    'paymentCollected.collected': true,
                    status: { $in: ['sample_collected', 'at_lab', 'completed'] },
                }
            },
            {
                $group: {
                    _id: null,
                    pendingAmount: { $sum: '$financials.adminAmount' },
                    orderCount: { $sum: 1 },
                }
            }
        ]);

        // Get labs with commission stats
        const labsStats = await Lab.aggregate([
            { $match: { status: 'Active' } },
            {
                $group: {
                    _id: null,
                    labCount: { $sum: 1 },
                    avgCommissionRate: { $avg: '$commissionRate' },
                }
            }
        ]);

        // Get recent transactions
        const recentTransactions = await Transaction.find()
            .populate('nurseId', 'name email phone')
            .populate('labId', 'name')
            .populate('processedBy', 'name')
            .sort({ createdAt: -1 })
            .limit(10);

        res.json({
            success: true,
            data: {
                overview: {
                    totalRevenue: ordersStats[0]?.totalRevenue || 0,
                    totalAdminAmount: ordersStats[0]?.totalAdminAmount || 0,
                    totalLabAmount: ordersStats[0]?.totalLabAmount || 0,
                    totalNurseNetEarning: ordersStats[0]?.totalNurseNetEarning || 0,
                    orderCount: ordersStats[0]?.orderCount || 0,
                    completedOrders: ordersStats[0]?.completedOrders || 0,
                },
                nurseStats: {
                    totalNurseBalance: nurseBalances[0]?.totalBalance || 0,
                    totalNurseEarnings: nurseBalances[0]?.totalEarnings || 0,
                    totalPaidToAdmin: nurseBalances[0]?.totalPaidToAdmin || 0,
                    nurseCount: nurseBalances[0]?.nurseCount || 0,
                },
                pendingSettlements: {
                    labAmount: pendingLabSettlements[0]?.pendingAmount || 0,
                    labOrderCount: pendingLabSettlements[0]?.orderCount || 0,
                    adminAmount: pendingAdminSettlements[0]?.pendingAmount || 0,
                    adminOrderCount: pendingAdminSettlements[0]?.orderCount || 0,
                },
                labStats: {
                    labCount: labsStats[0]?.labCount || 0,
                    avgCommissionRate: labsStats[0]?.avgCommissionRate || 0,
                },
                recentTransactions,
            }
        });
    } catch (error) {
        console.error('Error fetching finance overview:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch finance overview' });
    }
});

// ==================== PENDING ADMIN SETTLEMENTS ====================

/**
 * GET /api/admin/finance/pending-admin-settlements
 * Get all orders with pending admin settlements (what nurses owe admin)
 * Aggregated by nurse for dashboard display
 */
router.get('/pending-admin-settlements', verifyToken, adminOnly, async (req, res) => {
    try {
        // Aggregate settlements by nurse
        const aggregatedSettlements = await Order.aggregate([
            {
                $match: {
                    'paymentCollected.collected': true,
                    'financials.adminSettled': false,
                    status: { $in: ['sample_collected', 'at_lab', 'completed'] },
                    nurseId: { $ne: null }
                }
            },
            {
                $group: {
                    _id: {
                        nurseId: '$nurseId',
                        labId: '$labId'
                    },
                    orderCount: { $sum: 1 },
                    totalAmount: { $sum: { $ifNull: ['$pricing.total', 0] } },
                    adminAmount: { $sum: { $ifNull: ['$financials.adminAmount', 0] } },
                    nurseNetEarning: { $sum: { $ifNull: ['$financials.nurseNetEarning', 0] } },
                    labAmount: { $sum: { $ifNull: ['$financials.labAmount', 0] } },
                    latestOrderDate: { $max: '$paymentCollected.collectedAt' },
                    nurseCommissionRate: { $first: '$financials.nurseCommissionRate' }
                }
            },
            {
                $lookup: {
                    from: 'users',
                    localField: '_id.nurseId',
                    foreignField: '_id',
                    as: 'nurseInfo'
                }
            },
            {
                $lookup: {
                    from: 'labs',
                    localField: '_id.labId',
                    foreignField: '_id',
                    as: 'labInfo'
                }
            },
            {
                $project: {
                    _id: 0,
                    nurseId: {
                        _id: '$_id.nurseId',
                        name: { $arrayElemAt: ['$nurseInfo.name', 0] },
                        phone: { $arrayElemAt: ['$nurseInfo.phone', 0] },
                        email: { $arrayElemAt: ['$nurseInfo.email', 0] },
                        nurseBalance: { $arrayElemAt: ['$nurseInfo.nurseBalance', 0] }
                    },
                    labId: {
                        _id: '$_id.labId',
                        name: { $arrayElemAt: ['$labInfo.name', 0] }
                    },
                    orderCount: 1,
                    totalAmount: 1,
                    adminAmount: 1,
                    nurseNetEarning: 1,
                    labAmount: 1,
                    latestOrderDate: 1,
                    nurseCommissionRate: { $ifNull: ['$nurseCommissionRate', 0] }
                }
            },
            {
                $sort: { latestOrderDate: -1 }
            }
        ]);

        // Calculate totals
        const totalAdminAmount = aggregatedSettlements.reduce(
            (sum, s) => sum + (s.adminAmount || 0), 0
        );
        const totalOrders = aggregatedSettlements.reduce(
            (sum, s) => sum + (s.orderCount || 0), 0
        );

        res.json({
            success: true,
            data: {
                settlements: aggregatedSettlements,
                totalAdminAmount,
                total: totalOrders,
                settlementCount: aggregatedSettlements.length
            }
        });
    } catch (error) {
        console.error('Error fetching pending admin settlements:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch pending admin settlements' });
    }
});

// ==================== NURSE BALANCE MANAGEMENT ====================

/**
 * GET /api/admin/finance/nurses
 * Get all nurses with their balances
 */
router.get('/nurses', verifyToken, adminOnly, async (req, res) => {
    try {
        const { page = 1, limit = 20, search, sortBy = 'nurseBalance', sortOrder = 'desc' } = req.query;
        const skip = (page - 1) * limit;

        let query = { role: 'nurse' };
        if (search) {
            query.$or = [
                { name: { $regex: search, $options: 'i' } },
                { email: { $regex: search, $options: 'i' } },
                { phone: { $regex: search, $options: 'i' } },
            ];
        }

        const sortOptions = {};
        sortOptions[sortBy] = sortOrder === 'asc' ? 1 : -1;

        const nurses = await User.find(query)
            .select('name email phone nurseBalance totalEarnings totalPaidToAdmin lastSettlementDate nurseCommissionRate createdAt')
            .sort(sortOptions)
            .skip(skip)
            .limit(parseInt(limit));

        const total = await User.countDocuments(query);

        // Get additional stats for each nurse
        const nursesWithStats = await Promise.all(nurses.map(async (nurse) => {
            const orderStats = await Order.aggregate([
                { $match: { nurseId: nurse._id, 'paymentCollected.collected': true } },
                {
                    $group: {
                        _id: null,
                        totalOrders: { $sum: 1 },
                        totalCollected: { $sum: '$pricing.total' },
                        totalAdminAmount: { $sum: '$financials.adminAmount' },
                        totalNurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                    }
                }
            ]);

            // Get pending admin settlements for this nurse
            const pendingAdmin = await Order.aggregate([
                { 
                    $match: { 
                        nurseId: nurse._id, 
                        'paymentCollected.collected': true,
                        'financials.adminSettled': false,
                    } 
                },
                {
                    $group: {
                        _id: null,
                        pendingAmount: { $sum: '$financials.adminAmount' },
                        orderCount: { $sum: 1 },
                    }
                }
            ]);

            return {
                ...nurse.toObject(),
                stats: {
                    totalOrders: orderStats[0]?.totalOrders || 0,
                    totalCollected: orderStats[0]?.totalCollected || 0,
                    totalAdminAmount: orderStats[0]?.totalAdminAmount || 0,
                    totalNurseNetEarning: orderStats[0]?.totalNurseNetEarning || 0,
                    pendingAdminSettlement: pendingAdmin[0]?.pendingAmount || 0,
                    pendingOrderCount: pendingAdmin[0]?.orderCount || 0,
                }
            };
        }));

        res.json({
            success: true,
            data: {
                nurses: nursesWithStats,
                total,
                page: parseInt(page),
                pages: Math.ceil(total / limit),
            }
        });
    } catch (error) {
        console.error('Error fetching nurses:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch nurses' });
    }
});

/**
 * GET /api/admin/finance/nurses/:nurseId
 * Get detailed nurse financial info
 */
router.get('/nurses/:nurseId', verifyToken, adminOnly, async (req, res) => {
    try {
        const { nurseId } = req.params;

        const nurse = await User.findById(nurseId)
            .select('name email phone nurseBalance totalEarnings totalPaidToAdmin lastSettlementDate nurseCommissionRate createdAt');

        if (!nurse) {
            return res.status(404).json({ success: false, message: 'Nurse not found' });
        }

        // Get order stats
        const orderStats = await Order.aggregate([
            { $match: { nurseId: nurse._id } },
            {
                $group: {
                    _id: null,
                    totalOrders: { $sum: 1 },
                    completedOrders: {
                        $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] }
                    },
                    totalCollected: {
                        $sum: { $cond: ['$paymentCollected.collected', '$pricing.total', 0] }
                    },
                }
            }
        ]);

        // Get recent orders
        const recentOrders = await Order.find({ nurseId })
            .populate('labId', 'name')
            .select('qrCode pricing.total financials labId createdAt status')
            .sort({ createdAt: -1 })
            .limit(10);

        // Get transaction history
        const transactions = await Transaction.find({ nurseId })
            .populate('labId', 'name')
            .populate('processedBy', 'name')
            .sort({ createdAt: -1 })
            .limit(50);

        // Get monthly earnings summary
        const monthlySummary = await Order.aggregate([
            { $match: { nurseId: nurse._id, 'paymentCollected.collected': true } },
            {
                $group: {
                    _id: {
                        year: { $year: '$paymentCollected.collectedAt' },
                        month: { $month: '$paymentCollected.collectedAt' },
                    },
                    totalOrders: { $sum: 1 },
                    totalAmount: { $sum: '$pricing.total' },
                    totalAdminAmount: { $sum: '$financials.adminAmount' },
                    totalNurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                }
            },
            { $sort: { '_id.year': -1, '_id.month': -1 } },
            { $limit: 12 }
        ]);

        // Get pending admin settlements for this nurse
        const pendingAdminSettlements = await Order.find({
            nurseId: nurse._id,
            'paymentCollected.collected': true,
            'financials.adminSettled': false,
            status: { $in: ['sample_collected', 'at_lab', 'completed'] },
        })
        .populate('labId', 'name')
        .select('qrCode pricing.total financials labId createdAt paymentCollected.collectedAt');

        const totalPendingAdminAmount = pendingAdminSettlements.reduce(
            (sum, order) => sum + (order.financials?.adminAmount || 0), 0
        );

        res.json({
            success: true,
            data: {
                nurse,
                stats: {
                    totalOrders: orderStats[0]?.totalOrders || 0,
                    completedOrders: orderStats[0]?.completedOrders || 0,
                    totalCollected: orderStats[0]?.totalCollected || 0,
                },
                recentOrders,
                transactions,
                monthlySummary,
                pendingAdminSettlements: {
                    totalAmount: totalPendingAdminAmount,
                    orders: pendingAdminSettlements,
                },
            }
        });
    } catch (error) {
        console.error('Error fetching nurse details:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch nurse details' });
    }
});

/**
 * POST /api/admin/finance/nurses/:nurseId/settle
 * Settle nurse balance (nurse pays admin)
 */
router.post('/nurses/:nurseId/settle', verifyToken, adminOnly, async (req, res) => {
    try {
        const { nurseId } = req.params;
        const { amount, notes } = req.body;

        const nurse = await User.findById(nurseId);
        if (!nurse || nurse.role !== 'nurse') {
            return res.status(404).json({ success: false, message: 'Nurse not found' });
        }

        const settleAmount = amount !== undefined ? parseFloat(amount) : nurse.nurseBalance;

        if (settleAmount <= 0) {
            return res.status(400).json({ success: false, message: 'Settlement amount must be greater than 0' });
        }

        if (settleAmount > nurse.nurseBalance) {
            return res.status(400).json({ success: false, message: 'Settlement amount exceeds nurse balance' });
        }

        // Create transaction record
        const transaction = new Transaction({
            type: 'admin_settlement',
            amount: settleAmount,
            nurseId: nurse._id,
            processedBy: req.user.id,
            description: notes || `Balance settlement - Nurse paid ${settleAmount} IQD to admin`,
            referenceNumber: Transaction.generateReferenceNumber('admin_settlement'),
            balanceAfter: {
                nurseBalance: nurse.nurseBalance - settleAmount,
            },
        });
        await transaction.save();

        // Update nurse balance
        nurse.nurseBalance -= settleAmount;
        nurse.totalPaidToAdmin += settleAmount;
        nurse.lastSettlementDate = new Date();
        await nurse.save();

        // If balance is now 0, mark all pending admin settlements as settled
        if (nurse.nurseBalance === 0) {
            await Order.updateMany(
                {
                    nurseId: nurse._id,
                    'paymentCollected.collected': true,
                    'financials.adminSettled': false,
                    status: { $in: ['sample_collected', 'at_lab', 'completed'] },
                },
                {
                    $set: {
                        'financials.adminSettled': true,
                        'financials.adminSettledAt': new Date(),
                    }
                }
            );
        }

        res.json({
            success: true,
            message: `Successfully settled ${settleAmount} IQD from nurse balance`,
            data: {
                nurse: {
                    id: nurse._id,
                    name: nurse.name,
                    newBalance: nurse.nurseBalance,
                    totalPaidToAdmin: nurse.totalPaidToAdmin,
                },
                transaction,
            }
        });
    } catch (error) {
        console.error('Error settling nurse balance:', error);
        res.status(500).json({ success: false, message: 'Failed to settle nurse balance' });
    }
});

/**
 * POST /api/admin/finance/nurses/:nurseId/reset
 * Reset nurse balance to 0 (full settlement)
 */
router.post('/nurses/:nurseId/reset', verifyToken, adminOnly, async (req, res) => {
    try {
        const { nurseId } = req.params;
        const { notes } = req.body;

        const nurse = await User.findById(nurseId);
        if (!nurse || nurse.role !== 'nurse') {
            return res.status(404).json({ success: false, message: 'Nurse not found' });
        }

        const currentBalance = nurse.nurseBalance;

        if (currentBalance <= 0) {
            return res.status(400).json({ success: false, message: 'Nurse balance is already 0' });
        }

        // Create transaction record
        const transaction = new Transaction({
            type: 'admin_settlement',
            amount: currentBalance,
            nurseId: nurse._id,
            processedBy: req.user.id,
            description: notes || `Full balance reset - Nurse paid ${currentBalance} IQD to admin`,
            referenceNumber: Transaction.generateReferenceNumber('admin_settlement'),
            balanceAfter: {
                nurseBalance: 0,
            },
        });
        await transaction.save();

        // Reset nurse balance
        nurse.nurseBalance = 0;
        nurse.totalPaidToAdmin += currentBalance;
        nurse.lastSettlementDate = new Date();
        await nurse.save();

        // Mark all pending admin settlements as settled for this nurse
        await Order.updateMany(
            {
                nurseId: nurse._id,
                'paymentCollected.collected': true,
                'financials.adminSettled': false,
                status: { $in: ['sample_collected', 'at_lab', 'completed'] },
            },
            {
                $set: {
                    'financials.adminSettled': true,
                    'financials.adminSettledAt': new Date(),
                }
            }
        );

        res.json({
            success: true,
            message: `Successfully reset nurse balance. Settled ${currentBalance} IQD`,
            data: {
                nurse: {
                    id: nurse._id,
                    name: nurse.name,
                    settledAmount: currentBalance,
                    newBalance: 0,
                    totalPaidToAdmin: nurse.totalPaidToAdmin,
                },
                transaction,
            }
        });
    } catch (error) {
        console.error('Error resetting nurse balance:', error);
        res.status(500).json({ success: false, message: 'Failed to reset nurse balance' });
    }
});

/**
 * POST /api/admin/finance/nurses/:nurseId/adjust
 * Adjust nurse balance (correction)
 */
router.post('/nurses/:nurseId/adjust', verifyToken, adminOnly, async (req, res) => {
    try {
        const { nurseId } = req.params;
        const { amount, reason } = req.body;

        if (!amount || !reason) {
            return res.status(400).json({ success: false, message: 'Amount and reason are required' });
        }

        const nurse = await User.findById(nurseId);
        if (!nurse || nurse.role !== 'nurse') {
            return res.status(404).json({ success: false, message: 'Nurse not found' });
        }

        const adjustAmount = parseFloat(amount);
        const newBalance = nurse.nurseBalance + adjustAmount;

        if (newBalance < 0) {
            return res.status(400).json({ success: false, message: 'Adjustment would result in negative balance' });
        }

        // Create transaction record
        const transaction = new Transaction({
            type: 'balance_adjustment',
            amount: Math.abs(adjustAmount),
            nurseId: nurse._id,
            processedBy: req.user.id,
            description: `Balance adjustment: ${adjustAmount > 0 ? '+' : ''}${adjustAmount} IQD - ${reason}`,
            referenceNumber: Transaction.generateReferenceNumber('balance_adjustment'),
            balanceAfter: {
                nurseBalance: newBalance,
            },
            metadata: {
                adjustmentType: adjustAmount > 0 ? 'credit' : 'debit',
                reason,
            },
        });
        await transaction.save();

        // Update nurse balance
        nurse.nurseBalance = newBalance;
        await nurse.save();

        res.json({
            success: true,
            message: `Successfully adjusted nurse balance by ${adjustAmount} IQD`,
            data: {
                nurse: {
                    id: nurse._id,
                    name: nurse.name,
                    previousBalance: nurse.nurseBalance - adjustAmount,
                    adjustment: adjustAmount,
                    newBalance: nurse.nurseBalance,
                },
                transaction,
            }
        });
    } catch (error) {
        console.error('Error adjusting nurse balance:', error);
        res.status(500).json({ success: false, message: 'Failed to adjust nurse balance' });
    }
});

// ==================== LAB FINANCIAL MANAGEMENT ====================

/**
 * GET /api/admin/finance/labs
 * Get all labs with their financial stats
 */
router.get('/labs', verifyToken, adminOnly, async (req, res) => {
    try {
        const { page = 1, limit = 20, search } = req.query;
        const skip = (page - 1) * limit;

        let query = { status: 'Active' };
        if (search) {
            query.$or = [
                { name: { $regex: search, $options: 'i' } },
                { email: { $regex: search, $options: 'i' } },
            ];
        }

        const labs = await Lab.find(query)
            .select('name email phone city commissionRate status')
            .sort({ name: 1 })
            .skip(skip)
            .limit(parseInt(limit));

        const total = await Lab.countDocuments(query);

        // Get financial stats for each lab
        const labsWithStats = await Promise.all(labs.map(async (lab) => {
            const stats = await Order.aggregate([
                { $match: { labId: lab._id, status: { $nin: ['cancelled'] } } },
                {
                    $group: {
                        _id: null,
                        totalOrders: { $sum: 1 },
                        totalRevenue: { $sum: '$pricing.total' },
                        labAmount: { $sum: '$financials.labAmount' },
                        adminAmount: { $sum: '$financials.adminAmount' },
                        completedOrders: {
                            $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] }
                        },
                    }
                }
            ]);

            // Get pending settlements
            const pendingSettlements = await Order.aggregate([
                {
                    $match: {
                        labId: lab._id,
                        'financials.labSettled': false,
                        'paymentCollected.collected': true,
                    }
                },
                {
                    $group: {
                        _id: null,
                        pendingAmount: { $sum: '$financials.labAmount' },
                        orderCount: { $sum: 1 },
                    }
                }
            ]);

            return {
                ...lab.toObject(),
                stats: {
                    totalOrders: stats[0]?.totalOrders || 0,
                    totalRevenue: stats[0]?.totalRevenue || 0,
                    labAmount: stats[0]?.labAmount || 0,
                    adminAmount: stats[0]?.adminAmount || 0,
                    completedOrders: stats[0]?.completedOrders || 0,
                },
                pendingSettlements: {
                    amount: pendingSettlements[0]?.pendingAmount || 0,
                    orderCount: pendingSettlements[0]?.orderCount || 0,
                },
            };
        }));

        res.json({
            success: true,
            data: {
                labs: labsWithStats,
                total,
                page: parseInt(page),
                pages: Math.ceil(total / limit),
            }
        });
    } catch (error) {
        console.error('Error fetching labs:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch labs' });
    }
});

/**
 * GET /api/admin/finance/labs/:labId
 * Get detailed lab financial info
 */
router.get('/labs/:labId', verifyToken, adminOnly, async (req, res) => {
    try {
        const { labId } = req.params;

        const lab = await Lab.findById(labId)
            .populate('ownerId', 'name email phone');

        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }

        // Get order history
        const orders = await Order.find({ labId })
            .populate('nurseId', 'name phone')
            .populate('patientId', 'name')
            .sort({ createdAt: -1 })
            .limit(50);

        // Get monthly revenue summary
        const monthlySummary = await Order.aggregate([
            { $match: { labId: lab._id, status: { $nin: ['cancelled'] } } },
            {
                $group: {
                    _id: {
                        year: { $year: '$createdAt' },
                        month: { $month: '$createdAt' },
                    },
                    totalOrders: { $sum: 1 },
                    totalRevenue: { $sum: '$pricing.total' },
                    labAmount: { $sum: '$financials.labAmount' },
                    adminAmount: { $sum: '$financials.adminAmount' },
                }
            },
            { $sort: { '_id.year': -1, '_id.month': -1 } },
            { $limit: 12 }
        ]);

        res.json({
            success: true,
            data: {
                lab,
                orders,
                monthlySummary,
            }
        });
    } catch (error) {
        console.error('Error fetching lab details:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch lab details' });
    }
});

/**
 * PUT /api/admin/finance/labs/:labId/commission
 * Update lab commission rate
 */
router.put('/labs/:labId/commission', verifyToken, adminOnly, async (req, res) => {
    try {
        const { labId } = req.params;
        const { commissionRate } = req.body;

        if (commissionRate === undefined || commissionRate < 0 || commissionRate > 100) {
            return res.status(400).json({ success: false, message: 'Commission rate must be between 0 and 100' });
        }

        const lab = await Lab.findByIdAndUpdate(
            labId,
            { commissionRate, lastUpdatedBy: req.user.id },
            { new: true }
        );

        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }

        res.json({
            success: true,
            message: `Commission rate updated to ${commissionRate}%`,
            data: { lab }
        });
    } catch (error) {
        console.error('Error updating commission rate:', error);
        res.status(500).json({ success: false, message: 'Failed to update commission rate' });
    }
});

// ==================== TRANSACTION HISTORY ====================

/**
 * GET /api/admin/finance/transactions
 * Get all transactions with filtering
 */
router.get('/transactions', verifyToken, adminOnly, async (req, res) => {
    try {
        const {
            page = 1,
            limit = 50,
            type,
            nurseId,
            labId,
            startDate,
            endDate,
            status,
        } = req.query;
        const skip = (page - 1) * limit;

        const query = {};
        if (type) query.type = type;
        if (nurseId) query.nurseId = nurseId;
        if (labId) query.labId = labId;
        if (status) query.status = status;
        if (startDate || endDate) {
            query.createdAt = {};
            if (startDate) query.createdAt.$gte = new Date(startDate);
            if (endDate) query.createdAt.$lte = new Date(endDate);
        }

        const transactions = await Transaction.find(query)
            .populate('nurseId', 'name email phone')
            .populate('labId', 'name')
            .populate('patientId', 'name')
            .populate('processedBy', 'name')
            .populate('orderId', 'qrCode pricing.total')
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(parseInt(limit));

        const total = await Transaction.countDocuments(query);

        // Get summary stats
        const summary = await Transaction.aggregate([
            { $match: query },
            {
                $group: {
                    _id: '$type',
                    totalAmount: { $sum: '$amount' },
                    count: { $sum: 1 },
                }
            }
        ]);

        res.json({
            success: true,
            data: {
                transactions,
                total,
                page: parseInt(page),
                pages: Math.ceil(total / limit),
                summary,
            }
        });
    } catch (error) {
        console.error('Error fetching transactions:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch transactions' });
    }
});

// ==================== REPORTS ====================

/**
 * GET /api/admin/finance/reports/monthly
 * Get monthly financial report
 */
router.get('/reports/monthly', verifyToken, adminOnly, async (req, res) => {
    try {
        const { year, month } = req.query;
        const targetYear = parseInt(year) || new Date().getFullYear();
        const targetMonth = parseInt(month) || new Date().getMonth() + 1;

        const startDate = new Date(targetYear, targetMonth - 1, 1);
        const endDate = new Date(targetYear, targetMonth, 0, 23, 59, 59);

        // Revenue by lab
        const labRevenue = await Order.aggregate([
            {
                $match: {
                    createdAt: { $gte: startDate, $lte: endDate },
                    status: { $nin: ['cancelled'] },
                }
            },
            {
                $group: {
                    _id: '$labId',
                    totalOrders: { $sum: 1 },
                    totalRevenue: { $sum: '$pricing.total' },
                    labAmount: { $sum: '$financials.labAmount' },
                    adminAmount: { $sum: '$financials.adminAmount' },
                }
            },
            {
                $lookup: {
                    from: 'labs',
                    localField: '_id',
                    foreignField: '_id',
                    as: 'lab'
                }
            },
            { $unwind: '$lab' },
            {
                $project: {
                    labName: '$lab.name',
                    commissionRate: '$lab.commissionRate',
                    totalOrders: 1,
                    totalRevenue: 1,
                    labAmount: 1,
                    adminAmount: 1,
                }
            },
            { $sort: { totalRevenue: -1 } }
        ]);

        // Earnings by nurse
        const nurseEarnings = await Order.aggregate([
            {
                $match: {
                    createdAt: { $gte: startDate, $lte: endDate },
                    nurseId: { $ne: null },
                    status: { $nin: ['cancelled'] },
                }
            },
            {
                $group: {
                    _id: '$nurseId',
                    totalOrders: { $sum: 1 },
                    totalCollected: { $sum: '$pricing.total' },
                    totalAdminAmount: { $sum: '$financials.adminAmount' },
                    totalNurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                }
            },
            {
                $lookup: {
                    from: 'users',
                    localField: '_id',
                    foreignField: '_id',
                    as: 'nurse'
                }
            },
            { $unwind: '$nurse' },
            {
                $project: {
                    nurseName: '$nurse.name',
                    nursePhone: '$nurse.phone',
                    nurseBalance: '$nurse.nurseBalance',
                    nurseCommissionRate: '$nurse.nurseCommissionRate',
                    totalOrders: 1,
                    totalCollected: 1,
                    totalAdminAmount: 1,
                    totalNurseNetEarning: 1,
                }
            },
            { $sort: { totalAdminAmount: -1 } }
        ]);

        // Daily breakdown
        const dailyBreakdown = await Order.aggregate([
            {
                $match: {
                    createdAt: { $gte: startDate, $lte: endDate },
                    status: { $nin: ['cancelled'] },
                }
            },
            {
                $group: {
                    _id: { $dayOfMonth: '$createdAt' },
                    totalOrders: { $sum: 1 },
                    totalRevenue: { $sum: '$pricing.total' },
                    adminAmount: { $sum: '$financials.adminAmount' },
                }
            },
            { $sort: { _id: 1 } }
        ]);

        // Overall totals
        const totals = await Order.aggregate([
            {
                $match: {
                    createdAt: { $gte: startDate, $lte: endDate },
                    status: { $nin: ['cancelled'] },
                }
            },
            {
                $group: {
                    _id: null,
                    totalOrders: { $sum: 1 },
                    totalRevenue: { $sum: '$pricing.total' },
                    totalLabAmount: { $sum: '$financials.labAmount' },
                    totalAdminAmount: { $sum: '$financials.adminAmount' },
                    totalNurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                }
            }
        ]);

        res.json({
            success: true,
            data: {
                period: {
                    year: targetYear,
                    month: targetMonth,
                    startDate,
                    endDate,
                },
                totals: totals[0] || {
                    totalOrders: 0,
                    totalRevenue: 0,
                    totalLabAmount: 0,
                    totalAdminAmount: 0,
                    totalNurseNetEarning: 0,
                },
                labRevenue,
                nurseEarnings,
                dailyBreakdown,
            }
        });
    } catch (error) {
        console.error('Error generating monthly report:', error);
        res.status(500).json({ success: false, message: 'Failed to generate monthly report' });
    }
});

// ==================== ADMIN SETTLEMENTS (What nurses owe admin) ====================

/**
 * GET /api/admin/finance/pending-admin-settlements
 * Get all orders where nurses owe admin (not yet settled)
 */
router.get('/pending-admin-settlements', verifyToken, adminOnly, async (req, res) => {
    try {
        const { nurseId, page = 1, limit = 50 } = req.query;
        const skip = (page - 1) * limit;

        const query = {
            'paymentCollected.collected': true,
            'financials.adminSettled': false,
            status: { $in: ['sample_collected', 'at_lab', 'completed'] },
        };

        if (nurseId) {
            query.nurseId = nurseId;
        }

        const orders = await Order.find(query)
            .populate('nurseId', 'name phone nurseCommissionRate')
            .populate('labId', 'name')
            .populate('patientId', 'name')
            .select('qrCode pricing.total financials nurseId labId patientId createdAt paymentCollected')
            .sort({ 'paymentCollected.collectedAt': -1 })
            .skip(skip)
            .limit(parseInt(limit));

        const total = await Order.countDocuments(query);

        // Group by nurse
        const byNurse = {};
        for (const order of orders) {
            const nId = order.nurseId?._id?.toString();
            if (!nId) continue;
            if (!byNurse[nId]) {
                byNurse[nId] = {
                    nurse: order.nurseId,
                    orders: [],
                    totalAdminAmount: 0,
                };
            }
            byNurse[nId].orders.push(order);
            byNurse[nId].totalAdminAmount += order.financials?.adminAmount || 0;
        }

        // Get overall total
        const overallTotal = await Order.aggregate([
            { $match: query },
            {
                $group: {
                    _id: null,
                    totalAdminAmount: { $sum: '$financials.adminAmount' },
                    orderCount: { $sum: 1 },
                }
            }
        ]);

        res.json({
            success: true,
            data: {
                orders,
                byNurse: Object.values(byNurse),
                total,
                page: parseInt(page),
                pages: Math.ceil(total / limit),
                overallTotal: {
                    totalAdminAmount: overallTotal[0]?.totalAdminAmount || 0,
                    orderCount: overallTotal[0]?.orderCount || 0,
                },
            }
        });
    } catch (error) {
        console.error('Error fetching pending admin settlements:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch pending admin settlements' });
    }
});

/**
 * POST /api/admin/finance/settle-admin/:orderId
 * Mark a specific order as settled (nurse paid admin)
 */
router.post('/settle-admin/:orderId', verifyToken, adminOnly, async (req, res) => {
    try {
        const { orderId } = req.params;
        const { notes } = req.body;

        const order = await Order.findById(orderId);
        if (!order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        if (!order.paymentCollected?.collected) {
            return res.status(400).json({ success: false, message: 'Payment not yet collected from patient' });
        }

        if (order.financials?.adminSettled) {
            return res.status(400).json({ success: false, message: 'Order already settled with admin' });
        }

        const adminAmount = order.financials?.adminAmount || 0;

        // Mark as settled
        order.financials.adminSettled = true;
        order.financials.adminSettledAt = new Date();
        order.financials.adminSettledBy = req.user.id;
        await order.save();

        // Update nurse balance
        const nurse = await User.findById(order.nurseId);
        if (nurse) {
            nurse.nurseBalance = Math.max(0, (nurse.nurseBalance || 0) - adminAmount);
            nurse.totalPaidToAdmin = (nurse.totalPaidToAdmin || 0) + adminAmount;
            nurse.lastSettlementDate = new Date();
            await nurse.save();
        }

        // Create transaction record
        const transaction = new Transaction({
            type: 'admin_settlement',
            amount: adminAmount,
            orderId: order._id,
            nurseId: order.nurseId,
            processedBy: req.user.id,
            description: notes || `Admin settlement for order ${order.qrCode}`,
            referenceNumber: Transaction.generateReferenceNumber('admin_settlement'),
        });
        await transaction.save();

        res.json({
            success: true,
            message: 'Order marked as settled with admin',
            data: {
                order: {
                    id: order._id,
                    qrCode: order.qrCode,
                    adminAmount,
                    settledAt: order.financials.adminSettledAt,
                },
                transaction,
            }
        });
    } catch (error) {
        console.error('Error settling with admin:', error);
        res.status(500).json({ success: false, message: 'Failed to settle with admin' });
    }
});

/**
 * POST /api/admin/finance/settle-admin-batch
 * Batch settle multiple orders (nurse paid admin for multiple orders)
 */
router.post('/settle-admin-batch', verifyToken, adminOnly, async (req, res) => {
    try {
        const { orderIds, notes } = req.body;

        if (!orderIds || !Array.isArray(orderIds) || orderIds.length === 0) {
            return res.status(400).json({ success: false, message: 'Order IDs are required' });
        }

        const orders = await Order.find({
            _id: { $in: orderIds },
            'paymentCollected.collected': true,
            'financials.adminSettled': false,
        });

        if (orders.length === 0) {
            return res.status(400).json({ success: false, message: 'No valid orders found to settle' });
        }

        let totalSettled = 0;
        const settledOrders = [];
        const nurseUpdates = {};

        for (const order of orders) {
            const adminAmount = order.financials?.adminAmount || 0;

            // Mark as settled
            order.financials.adminSettled = true;
            order.financials.adminSettledAt = new Date();
            order.financials.adminSettledBy = req.user.id;
            await order.save();

            // Track nurse updates
            const nurseId = order.nurseId?.toString();
            if (nurseId) {
                if (!nurseUpdates[nurseId]) {
                    nurseUpdates[nurseId] = { totalAmount: 0 };
                }
                nurseUpdates[nurseId].totalAmount += adminAmount;
            }

            // Create transaction
            const transaction = new Transaction({
                type: 'admin_settlement',
                amount: adminAmount,
                orderId: order._id,
                nurseId: order.nurseId,
                processedBy: req.user.id,
                description: notes || `Admin settlement for order ${order.qrCode}`,
                referenceNumber: Transaction.generateReferenceNumber('admin_settlement'),
            });
            await transaction.save();

            totalSettled += adminAmount;
            settledOrders.push({
                orderId: order._id,
                qrCode: order.qrCode,
                amount: adminAmount,
            });
        }

        // Update nurse balances
        for (const [nurseId, data] of Object.entries(nurseUpdates)) {
            await User.findByIdAndUpdate(nurseId, {
                $inc: {
                    nurseBalance: -data.totalAmount,
                    totalPaidToAdmin: data.totalAmount,
                },
                $set: { lastSettlementDate: new Date() },
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
        console.error('Error batch settling with admin:', error);
        res.status(500).json({ success: false, message: 'Failed to batch settle with admin' });
    }
});

/**
 * POST /api/admin/finance/settle-nurse/:nurseId
 * Settle all pending orders for a specific nurse
 */
router.post('/settle-nurse/:nurseId', verifyToken, adminOnly, async (req, res) => {
    try {
        const { nurseId } = req.params;
        const { notes } = req.body;

        const nurse = await User.findById(nurseId);
        if (!nurse || nurse.role !== 'nurse') {
            return res.status(404).json({ success: false, message: 'Nurse not found' });
        }

        const pendingOrders = await Order.find({
            nurseId,
            'paymentCollected.collected': true,
            'financials.adminSettled': false,
            status: { $in: ['sample_collected', 'at_lab', 'completed'] },
        });

        if (pendingOrders.length === 0) {
            return res.status(400).json({ success: false, message: 'No pending orders to settle' });
        }

        let totalSettled = 0;
        const settledOrders = [];

        for (const order of pendingOrders) {
            const adminAmount = order.financials?.adminAmount || 0;

            order.financials.adminSettled = true;
            order.financials.adminSettledAt = new Date();
            order.financials.adminSettledBy = req.user.id;
            await order.save();

            // Create transaction
            const transaction = new Transaction({
                type: 'admin_settlement',
                amount: adminAmount,
                orderId: order._id,
                nurseId: nurse._id,
                processedBy: req.user.id,
                description: notes || `Admin settlement for order ${order.qrCode}`,
                referenceNumber: Transaction.generateReferenceNumber('admin_settlement'),
            });
            await transaction.save();

            totalSettled += adminAmount;
            settledOrders.push({
                orderId: order._id,
                qrCode: order.qrCode,
                amount: adminAmount,
            });
        }

        // Update nurse balance
        nurse.nurseBalance = Math.max(0, (nurse.nurseBalance || 0) - totalSettled);
        nurse.totalPaidToAdmin = (nurse.totalPaidToAdmin || 0) + totalSettled;
        nurse.lastSettlementDate = new Date();
        await nurse.save();

        res.json({
            success: true,
            message: `Successfully settled ${pendingOrders.length} orders for ${nurse.name}`,
            data: {
                nurse: {
                    id: nurse._id,
                    name: nurse.name,
                    newBalance: nurse.nurseBalance,
                    totalPaidToAdmin: nurse.totalPaidToAdmin,
                },
                totalSettled,
                settledOrders,
            }
        });
    } catch (error) {
        console.error('Error settling nurse orders:', error);
        res.status(500).json({ success: false, message: 'Failed to settle nurse orders' });
    }
});

// ==================== NURSE PROFIT REPORTS ====================

/**
 * GET /api/admin/finance/reports/nurse-profit
 * Get profit report for all nurses (monthly, yearly, all-time)
 */
router.get('/reports/nurse-profit', verifyToken, adminOnly, async (req, res) => {
    try {
        const { nurseId, period = 'all' } = req.query;

        let dateFilter = {};
        const now = new Date();

        if (period === 'monthly') {
            const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
            dateFilter = { $gte: monthStart };
        } else if (period === 'yearly') {
            const yearStart = new Date(now.getFullYear(), 0, 1);
            dateFilter = { $gte: yearStart };
        }

        const matchQuery = {
            'paymentCollected.collected': true,
        };
        
        if (Object.keys(dateFilter).length > 0) {
            matchQuery['paymentCollected.collectedAt'] = dateFilter;
        }
        
        if (nurseId) {
            matchQuery.nurseId = new (require('mongoose').Types.ObjectId)(nurseId);
        }

        const nurseProfits = await Order.aggregate([
            { $match: matchQuery },
            {
                $group: {
                    _id: '$nurseId',
                    totalOrders: { $sum: 1 },
                    totalCollected: { $sum: '$pricing.total' },
                    totalLabAmount: { $sum: '$financials.labAmount' },
                    totalAdminAmount: { $sum: '$financials.adminAmount' },
                    totalNurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                }
            },
            {
                $lookup: {
                    from: 'users',
                    localField: '_id',
                    foreignField: '_id',
                    as: 'nurse'
                }
            },
            { $unwind: '$nurse' },
            {
                $project: {
                    nurseId: '$_id',
                    nurseName: '$nurse.name',
                    nursePhone: '$nurse.phone',
                    nurseCommissionRate: '$nurse.nurseCommissionRate',
                    nurseBalance: '$nurse.nurseBalance',
                    totalPaidToAdmin: '$nurse.totalPaidToAdmin',
                    totalOrders: 1,
                    totalCollected: 1,
                    totalLabAmount: 1,
                    totalAdminAmount: 1,
                    totalNurseNetEarning: 1,
                }
            },
            { $sort: { totalAdminAmount: -1 } }
        ]);

        // Get overall summary
        const overallSummary = await Order.aggregate([
            { $match: matchQuery },
            {
                $group: {
                    _id: null,
                    totalOrders: { $sum: 1 },
                    totalCollected: { $sum: '$pricing.total' },
                    totalLabAmount: { $sum: '$financials.labAmount' },
                    totalAdminAmount: { $sum: '$financials.adminAmount' },
                    totalNurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                }
            }
        ]);

        // Get pending amounts (what's still owed)
        const pendingQuery = { ...matchQuery, 'financials.adminSettled': false };
        const pendingAmounts = await Order.aggregate([
            { $match: pendingQuery },
            {
                $group: {
                    _id: null,
                    totalPendingAdminAmount: { $sum: '$financials.adminAmount' },
                    orderCount: { $sum: 1 },
                }
            }
        ]);

        res.json({
            success: true,
            data: {
                period,
                nurseProfits,
                summary: overallSummary[0] || {
                    totalOrders: 0,
                    totalCollected: 0,
                    totalLabAmount: 0,
                    totalAdminAmount: 0,
                    totalNurseNetEarning: 0,
                },
                pending: pendingAmounts[0] || {
                    totalPendingAdminAmount: 0,
                    orderCount: 0,
                },
            }
        });
    } catch (error) {
        console.error('Error generating nurse profit report:', error);
        res.status(500).json({ success: false, message: 'Failed to generate nurse profit report' });
    }
});

/**
 * GET /api/admin/finance/reports/nurse-profit/:nurseId
 * Get detailed profit breakdown for a specific nurse
 */
router.get('/reports/nurse-profit/:nurseId', verifyToken, adminOnly, async (req, res) => {
    try {
        const { nurseId } = req.params;

        const nurse = await User.findById(nurseId)
            .select('name phone email nurseCommissionRate nurseBalance totalEarnings totalPaidToAdmin lastSettlementDate');

        if (!nurse || nurse.role !== 'nurse') {
            return res.status(404).json({ success: false, message: 'Nurse not found' });
        }

        // Monthly breakdown
        const monthlyBreakdown = await Order.aggregate([
            {
                $match: {
                    nurseId: nurse._id,
                    'paymentCollected.collected': true,
                }
            },
            {
                $group: {
                    _id: {
                        year: { $year: '$paymentCollected.collectedAt' },
                        month: { $month: '$paymentCollected.collectedAt' },
                    },
                    totalOrders: { $sum: 1 },
                    totalCollected: { $sum: '$pricing.total' },
                    totalLabAmount: { $sum: '$financials.labAmount' },
                    totalAdminAmount: { $sum: '$financials.adminAmount' },
                    totalNurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                }
            },
            { $sort: { '_id.year': -1, '_id.month': -1 } },
            { $limit: 12 }
        ]);

        // Yearly breakdown
        const yearlyBreakdown = await Order.aggregate([
            {
                $match: {
                    nurseId: nurse._id,
                    'paymentCollected.collected': true,
                }
            },
            {
                $group: {
                    _id: { $year: '$paymentCollected.collectedAt' },
                    totalOrders: { $sum: 1 },
                    totalCollected: { $sum: '$pricing.total' },
                    totalLabAmount: { $sum: '$financials.labAmount' },
                    totalAdminAmount: { $sum: '$financials.adminAmount' },
                    totalNurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                }
            },
            { $sort: { _id: -1 } }
        ]);

        // All-time totals
        const allTimeTotals = await Order.aggregate([
            {
                $match: {
                    nurseId: nurse._id,
                    'paymentCollected.collected': true,
                }
            },
            {
                $group: {
                    _id: null,
                    totalOrders: { $sum: 1 },
                    totalCollected: { $sum: '$pricing.total' },
                    totalLabAmount: { $sum: '$financials.labAmount' },
                    totalAdminAmount: { $sum: '$financials.adminAmount' },
                    totalNurseNetEarning: { $sum: '$financials.nurseNetEarning' },
                }
            }
        ]);

        // Pending settlements
        const pendingSettlements = await Order.aggregate([
            {
                $match: {
                    nurseId: nurse._id,
                    'paymentCollected.collected': true,
                    'financials.adminSettled': false,
                }
            },
            {
                $group: {
                    _id: null,
                    pendingAdminAmount: { $sum: '$financials.adminAmount' },
                    orderCount: { $sum: 1 },
                }
            }
        ]);

        res.json({
            success: true,
            data: {
                nurse,
                monthlyBreakdown,
                yearlyBreakdown,
                allTime: allTimeTotals[0] || {
                    totalOrders: 0,
                    totalCollected: 0,
                    totalLabAmount: 0,
                    totalAdminAmount: 0,
                    totalNurseNetEarning: 0,
                },
                pendingSettlements: pendingSettlements[0] || {
                    pendingAdminAmount: 0,
                    orderCount: 0,
                },
            }
        });
    } catch (error) {
        console.error('Error generating nurse profit details:', error);
        res.status(500).json({ success: false, message: 'Failed to generate nurse profit details' });
    }
});

// ==================== PATIENT FINANCE MANAGEMENT ====================

/**
 * GET /api/admin/finance/patients
 * Get all patients with their financial stats
 */
router.get('/patients', verifyToken, adminOnly, async (req, res) => {
    try {
        const { page = 1, limit = 20, search, sortBy = 'totalSpent', sortOrder = 'desc' } = req.query;
        const skip = (page - 1) * limit;

        let query = { role: 'patient' };
        if (search) {
            query.$or = [
                { name: { $regex: search, $options: 'i' } },
                { email: { $regex: search, $options: 'i' } },
                { phone: { $regex: search, $options: 'i' } },
            ];
        }

        const sortOptions = {};
        sortOptions[sortBy] = sortOrder === 'asc' ? 1 : -1;

        const patients = await User.find(query)
            .select('name email phone gender birthDate createdAt')
            .sort(sortOptions)
            .skip(skip)
            .limit(parseInt(limit));

        const total = await User.countDocuments(query);

        // Get financial stats for each patient
        const patientsWithStats = await Promise.all(patients.map(async (patient) => {
            const orderStats = await Order.aggregate([
                { $match: { patientId: patient._id, status: { $nin: ['cancelled'] } } },
                {
                    $group: {
                        _id: null,
                        totalOrders: { $sum: 1 },
                        totalSpent: { $sum: '$pricing.total' },
                        completedOrders: {
                            $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] }
                        },
                        averageOrderValue: { $avg: '$pricing.total' },
                    }
                }
            ]);

            // Get order breakdown by status
            const statusBreakdown = await Order.aggregate([
                { $match: { patientId: patient._id } },
                {
                    $group: {
                        _id: '$status',
                        count: { $sum: 1 },
                        totalAmount: { $sum: '$pricing.total' },
                    }
                }
            ]);

            // Get recent orders
            const recentOrders = await Order.find({ patientId: patient._id })
                .populate('labId', 'name')
                .select('qrCode pricing.total status createdAt')
                .sort({ createdAt: -1 })
                .limit(5);

            // Calculate total spent from completed/paid orders
            const totalSpent = await Order.aggregate([
                {
                    $match: {
                        patientId: patient._id,
                        'paymentCollected.collected': true,
                        status: { $nin: ['cancelled'] }
                    }
                },
                {
                    $group: {
                        _id: null,
                        total: { $sum: '$pricing.total' },
                    }
                }
            ]);

            return {
                ...patient.toObject(),
                stats: {
                    totalOrders: orderStats[0]?.totalOrders || 0,
                    totalSpent: totalSpent[0]?.total || 0,
                    completedOrders: orderStats[0]?.completedOrders || 0,
                    averageOrderValue: orderStats[0]?.averageOrderValue || 0,
                },
                statusBreakdown: statusBreakdown.reduce((acc, item) => {
                    acc[item._id] = { count: item.count, totalAmount: item.totalAmount };
                    return acc;
                }, {}),
                recentOrders,
            };
        }));

        // Sort by totalSpent after stats are calculated
        if (sortBy === 'totalSpent') {
            patientsWithStats.sort((a, b) => {
                return sortOrder === 'asc'
                    ? a.stats.totalSpent - b.stats.totalSpent
                    : b.stats.totalSpent - a.stats.totalSpent;
            });
        }

        res.json({
            success: true,
            data: {
                patients: patientsWithStats,
                total,
                page: parseInt(page),
                pages: Math.ceil(total / limit),
            }
        });
    } catch (error) {
        console.error('Error fetching patients:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch patients' });
    }
});

/**
 * GET /api/admin/finance/patients/:patientId
 * Get detailed patient financial info
 */
router.get('/patients/:patientId', verifyToken, adminOnly, async (req, res) => {
    try {
        const { patientId } = req.params;

        const patient = await User.findById(patientId)
            .select('name email phone gender birthDate createdAt defaultLocation role');

        if (!patient || patient.role !== 'patient') {
            return res.status(404).json({ success: false, message: 'Patient not found' });
        }

        // Get all orders
        const orders = await Order.find({ patientId })
            .populate('labId', 'name commissionRate')
            .populate('nurseId', 'name phone')
            .sort({ createdAt: -1 });

        // Calculate totals
        const totals = await Order.aggregate([
            { $match: { patientId: patient._id, status: { $nin: ['cancelled'] } } },
            {
                $group: {
                    _id: null,
                    totalOrders: { $sum: 1 },
                    totalSpent: { $sum: '$pricing.total' },
                    totalPaid: {
                        $sum: {
                            $cond: ['$paymentCollected.collected', '$pricing.total', 0]
                        }
                    },
                    totalAdminRevenue: { $sum: '$financials.adminAmount' },
                    totalLabRevenue: { $sum: '$financials.labAmount' },
                    totalNurseRevenue: { $sum: '$financials.nurseNetEarning' },
                }
            }
        ]);

        // Monthly breakdown
        const monthlyBreakdown = await Order.aggregate([
            {
                $match: {
                    patientId: patient._id,
                    'paymentCollected.collected': true,
                }
            },
            {
                $group: {
                    _id: {
                        year: { $year: '$paymentCollected.collectedAt' },
                        month: { $month: '$paymentCollected.collectedAt' },
                    },
                    totalOrders: { $sum: 1 },
                    totalSpent: { $sum: '$pricing.total' },
                }
            },
            { $sort: { '_id.year': -1, '_id.month': -1 } },
            { $limit: 12 }
        ]);

        // Orders by lab
        const labBreakdown = await Order.aggregate([
            { $match: { patientId: patient._id, status: { $nin: ['cancelled'] } } },
            {
                $group: {
                    _id: '$labId',
                    labName: { $first: '$labId' },
                    totalOrders: { $sum: 1 },
                    totalSpent: { $sum: '$pricing.total' },
                }
            },
            {
                $lookup: {
                    from: 'labs',
                    localField: '_id',
                    foreignField: '_id',
                    as: 'lab'
                }
            },
            { $unwind: '$lab' },
            {
                $project: {
                    labName: '$lab.name',
                    totalOrders: 1,
                    totalSpent: 1,
                }
            },
            { $sort: { totalSpent: -1 } }
        ]);

        res.json({
            success: true,
            data: {
                patient,
                orders,
                totals: totals[0] || {
                    totalOrders: 0,
                    totalSpent: 0,
                    totalPaid: 0,
                    totalAdminRevenue: 0,
                    totalLabRevenue: 0,
                    totalNurseRevenue: 0,
                },
                monthlyBreakdown,
                labBreakdown,
            }
        });
    } catch (error) {
        console.error('Error fetching patient details:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch patient details' });
    }
});

/**
 * GET /api/admin/finance/patients/top-spenders
 * Get top spending patients
 */
router.get('/patients/top-spenders', verifyToken, adminOnly, async (req, res) => {
    try {
        const { limit = 10, startDate, endDate } = req.query;

        const dateFilter = {};
        if (startDate || endDate) {
            dateFilter['paymentCollected.collectedAt'] = {};
            if (startDate) dateFilter['paymentCollected.collectedAt'].$gte = new Date(startDate);
            if (endDate) dateFilter['paymentCollected.collectedAt'].$lte = new Date(endDate);
        }

        const topSpenders = await Order.aggregate([
            {
                $match: {
                    'paymentCollected.collected': true,
                    status: { $nin: ['cancelled'] },
                    ...dateFilter,
                }
            },
            {
                $group: {
                    _id: '$patientId',
                    totalSpent: { $sum: '$pricing.total' },
                    totalOrders: { $sum: 1 },
                    lastOrderDate: { $max: '$paymentCollected.collectedAt' },
                }
            },
            {
                $lookup: {
                    from: 'users',
                    localField: '_id',
                    foreignField: '_id',
                    as: 'patient'
                }
            },
            { $unwind: '$patient' },
            {
                $project: {
                    patientId: '$_id',
                    name: '$patient.name',
                    phone: '$patient.phone',
                    email: '$patient.email',
                    totalSpent: 1,
                    totalOrders: 1,
                    lastOrderDate: 1,
                }
            },
            { $sort: { totalSpent: -1 } },
            { $limit: parseInt(limit) }
        ]);

        res.json({
            success: true,
            data: { topSpenders }
        });
    } catch (error) {
        console.error('Error fetching top spenders:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch top spenders' });
    }
});

/**
 * GET /api/admin/finance/nurses/:nurseId/orders
 * Get all orders for a specific nurse with full details
 */
router.get('/nurses/:nurseId/orders', verifyToken, adminOnly, async (req, res) => {
    try {
        const { nurseId } = req.params;
        const { limit = 100 } = req.query;

        // Verify nurse exists
        const nurse = await User.findById(nurseId);
        if (!nurse || nurse.role !== 'nurse') {
            return res.status(404).json({
                success: false,
                message: 'Nurse not found'
            });
        }

        // Get all orders for this nurse with populated references
        const orders = await Order.find({ nurseId })
            .populate('patientId', 'name phone email')
            .populate('labId', 'name address')
            .sort({ createdAt: -1 })
            .limit(parseInt(limit));

        res.json({
            success: true,
            data: {
                nurse: {
                    id: nurse._id,
                    name: nurse.name,
                    phone: nurse.phone,
                    commissionRate: nurse.nurseCommissionRate,
                    balance: nurse.nurseBalance,
                    totalEarnings: nurse.totalEarnings,
                    totalPaidToAdmin: nurse.totalPaidToAdmin
                },
                orders: orders || [],
                count: orders.length
            }
        });
    } catch (error) {
        console.error('Error fetching nurse orders:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch nurse orders' });
    }
});

module.exports = router;
