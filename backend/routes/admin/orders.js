const express = require('express');
const router = express.Router();
const Order = require('../../models/Order');
const Lab = require('../../models/Lab');
const User = require('../../models/User');
const auth = require('../../middleware/auth');
const telegramService = require('../../services/telegramService');
const fcmService = require('../../services/fcmService');
const { r2SingleUpload } = require('../../middleware/r2Upload');
const { pickNurseMapLocation } = require('../../helpers/nurseLocation');
const { cityToTopicKey } = require('../../utils/cities');

const uploadMedicinePhoto = r2SingleUpload('medicineQuotes', 'medicineImage', 'medicine-');

// Admin middleware
const requireAdmin = async (req, res, next) => {
    if (req.user.role !== 'admin') {
        return res.status(403).json({
            success: false,
            message: 'Access denied. Admin role required.'
        });
    }
    next();
};

// Get all pending orders (for admin dashboard)
router.get('/pending', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { page = 1, limit = 50 } = req.query;

        const orders = await Order.find({ status: 'pending' })
            .populate('patientId', 'name email phone')
            .populate('labId', 'name address email phone city country')
            .populate('nurseId', 'name email phone')
            .populate('adminConfirmation.confirmedBy', 'name email')
            .populate('payment.collectedBy', 'name email')
            .populate('paymentCollected.collectedBy', 'name email')
            .populate('cancellation.cancelledBy', 'name email')
            .sort({ createdAt: -1 })
            .limit(parseInt(limit))
            .skip((parseInt(page) - 1) * parseInt(limit));

        const total = await Order.countDocuments({ status: 'pending' });

        res.json({
            success: true,
            data: {
                orders: orders,
                total: total,
                page: parseInt(page),
                pages: Math.ceil(total / parseInt(limit))
            }
        });
    } catch (error) {
        console.error('Get pending orders error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get all orders with filters (admin dashboard)
router.get('/all', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { status, labId, patientId, page = 1, limit = 50, startDate, endDate } = req.query;

        const query = {};
        if (status) query.status = status;
        if (labId) query.labId = labId;
        if (patientId) query.patientId = patientId;
        if (startDate || endDate) {
            query.createdAt = {};
            if (startDate) query.createdAt.$gte = new Date(startDate);
            if (endDate) query.createdAt.$lte = new Date(endDate);
        }

        const orders = await Order.find(query)
            .populate('patientId', 'name email phone')
            .populate('labId', 'name address email phone city country')
            .populate('nurseId', 'name email phone')
            .populate('adminConfirmation.confirmedBy', 'name email')
            .populate('payment.collectedBy', 'name email')
            .populate('paymentCollected.collectedBy', 'name email')
            .populate('cancellation.cancelledBy', 'name email')
            .sort({ createdAt: -1 })
            .limit(parseInt(limit))
            .skip((parseInt(page) - 1) * parseInt(limit));

        const total = await Order.countDocuments(query);

        res.json({
            success: true,
            data: {
                orders: orders,
                total: total,
                page: parseInt(page),
                pages: Math.ceil(total / parseInt(limit))
            }
        });
    } catch (error) {
        console.error('Get all orders error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get single order details page
router.get('/:orderId/details', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { orderId } = req.params;

        const order = await Order.findById(orderId)
            .populate('patientId', 'name email phone')
            .populate('labId', 'name address email phone city country')
            .populate('nurseId', 'name email phone')
            .populate('adminConfirmation.confirmedBy', 'name email')
            .populate('payment.collectedBy', 'name email')
            .populate('paymentCollected.collectedBy', 'name email')
            .populate('cancellation.cancelledBy', 'name email');

        if (!order) {
            return res.status(404).render('error', {
                message: 'Order not found'
            });
        }

        res.render('dashboard/admin-order-details', {
            order,
            path: req.baseUrl
        });
    } catch (error) {
        console.error('Get order details error:', error);
        res.status(500).render('error', {
            message: 'Server error'
        });
    }
});

// Get single order data (API endpoint)
router.get('/:orderId', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { orderId } = req.params;

        const order = await Order.findById(orderId)
            .populate('patientId', 'name email phone')
            .populate('labId', 'name address email phone city country')
            .populate('nurseId', 'name email phone')
            .populate('adminConfirmation.confirmedBy', 'name email')
            .populate('payment.collectedBy', 'name email')
            .populate('paymentCollected.collectedBy', 'name email')
            .populate('cancellation.cancelledBy', 'name email');

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        res.json({
            success: true,
            data: {
                order
            }
        });
    } catch (error) {
        console.error('Get order error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Confirm order (admin action)
router.post('/:orderId/confirm', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { orderId } = req.params;
        const { notes } = req.body;
        const adminId = req.user.id;

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Check if order can be confirmed
        if (order.status !== 'pending') {
            return res.status(400).json({
                success: false,
                message: 'Order cannot be confirmed at this stage'
            });
        }

        // Use the instance method to confirm
        await order.confirmOrder(adminId, notes);

        // Send FCM notification to patient
        try {
            await fcmService.sendToUser(
                order.patientId._id || order.patientId,
                'تم تأكيد الطلب',
                'تم تأكيد طلبك وهو جاهز لتعيين ممرض/ة',
                {
                    type: 'order_accepted',
                    orderId: order._id.toString()
                }
            );
            console.log('FCM: Order confirmation notification sent to patient');
        } catch (fcmError) {
            console.error('FCM order confirmation error:', fcmError);
        }

        // Send FCM notification to nurses in the order's city
        try {
            // Get order with populated patient to get city
            const populatedOrder = await Order.findById(orderId).populate('patientId', 'city');
            const orderCity = order.location?.city || populatedOrder?.patientId?.city;

            if (orderCity) {
                // Stable ASCII key for the (Arabic) governorate name - a plain
                // ASCII-strip here would collapse every city into the same
                // empty-suffixed topic, so every nurse got every city's orders.
                const cityId = cityToTopicKey(orderCity);
                await fcmService.sendToTopic(
                    `nurse_city_${cityId}`,
                    'طلب جديد متاح',
                    `طلب جديد في ${orderCity} - ${order.tests?.length || 0} فحوصات`,
                    {
                        type: 'new_order_in_city',
                        orderId: order._id.toString(),
                        city: cityId,
                        testCount: String(order.tests?.length || 0)
                    }
                );
                console.log(`FCM: Nurse notification sent to nurse_city_${cityId}`);
            }
        } catch (fcmError) {
            console.error('FCM nurse notification error:', fcmError);
        }

        res.json({
            success: true,
            message: 'Order confirmed successfully',
            data: {
                order: order
            }
        });
    } catch (error) {
        console.error('Confirm order error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Mark a confirmed medicine-delivery order as delivered / completed
router.post('/:orderId/complete-delivery', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const order = await Order.findById(req.params.orderId);
        if (!order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }
        if (order.prescriptionType !== 'medicine') {
            return res.status(400).json({ success: false, message: 'Only medicine orders can be marked delivered this way' });
        }
        if (order.status !== 'confirmed') {
            return res.status(400).json({ success: false, message: 'Order must be confirmed before marking it delivered' });
        }
        await order.markDelivered(req.user.id);

        try {
            await fcmService.sendToUser(
                order.patientId,
                'تم توصيل طلبك',
                'تم توصيل الوصفة العلاجية. شكراً لاستخدامك لاب جو',
                { type: 'order_completed', orderId: order._id.toString() }
            );
        } catch (fcmError) {
            console.error('FCM delivery complete error:', fcmError);
        }

        res.json({ success: true, message: 'Order marked as delivered', data: { order } });
    } catch (error) {
        console.error('Complete delivery error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Haversine straight-line distance in kilometers between two coordinates
function distanceKm(lat1, lng1, lat2, lng2) {
    const toRad = (deg) => (deg * Math.PI) / 180;
    const R = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Get all labs, all nurses, and active orders for the admin overview map.
// Patient locations are only meant to be revealed one at a time (click an
// order in the list to show its pin) rather than plotted all at once.
router.get('/map/overview', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const labs = await Lab.find({ status: 'Active' }).select('name city coordinates');
        const nurses = await User.find({ role: 'nurse', status: 'active' })
            .select('name phone city currentLocation defaultLocation');

        const activeOrders = await Order.find({
            status: { $in: ['pending', 'confirmed', 'nurse_assigned', 'sample_collected', 'at_lab'] },
        })
            .populate('patientId', 'name')
            .populate('nurseId', 'name')
            .populate('labId', 'name')
            .select('qrCode status location patientId nurseId labId createdAt')
            .sort({ createdAt: -1 })
            .limit(200);

        res.json({
            success: true,
            data: {
                labs: labs.map((lab) => ({
                    id: lab._id,
                    name: lab.name,
                    city: lab.city,
                    latitude: lab.coordinates?.latitude ?? null,
                    longitude: lab.coordinates?.longitude ?? null,
                })),
                nurses: nurses.map((nurse) => {
                    const loc = nurse.currentLocation?.latitude != null
                        ? nurse.currentLocation
                        : nurse.defaultLocation?.coordinates;
                    return {
                        id: nurse._id,
                        name: nurse.name,
                        phone: nurse.phone,
                        city: nurse.city,
                        latitude: loc?.latitude ?? null,
                        longitude: loc?.longitude ?? null,
                    };
                }),
                orders: activeOrders.map((order) => ({
                    id: order._id,
                    qrCode: order.qrCode,
                    status: order.status,
                    patientName: order.patientId?.name || '',
                    nurseName: order.nurseId?.name || null,
                    labName: order.labId?.name || null,
                    latitude: order.location?.coordinates?.latitude ?? null,
                    longitude: order.location?.coordinates?.longitude ?? null,
                })),
            },
        });
    } catch (error) {
        console.error('Get map overview error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
        });
    }
});

// Get nearest available nurses and nearest labs for an order (for admin assignment UI)
router.get('/:orderId/assignment-options', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { orderId } = req.params;

        const order = await Order.findById(orderId);
        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        const patientLat = order.location?.coordinates?.latitude;
        const patientLng = order.location?.coordinates?.longitude;

        const nurses = await User.find({ role: 'nurse', status: 'active' })
            .select('name phone city averageRating currentLocation defaultLocation');

        const rankedNurses = nurses.map((nurse) => {
            // Prefer a live location (fresh within the last hour) over the nurse's saved default address
            const isFresh =
                nurse.currentLocation?.updatedAt &&
                Date.now() - new Date(nurse.currentLocation.updatedAt).getTime() < 60 * 60 * 1000;
            const loc = isFresh
                ? nurse.currentLocation
                : nurse.defaultLocation?.coordinates?.latitude != null
                    ? nurse.defaultLocation.coordinates
                    : null;

            const distance =
                loc && patientLat != null && patientLng != null
                    ? distanceKm(patientLat, patientLng, loc.latitude, loc.longitude)
                    : null;

            return {
                id: nurse._id,
                name: nurse.name,
                phone: nurse.phone,
                city: nurse.city,
                averageRating: nurse.averageRating,
                distanceKm: distance,
                hasLocation: distance !== null,
                latitude: loc?.latitude ?? null,
                longitude: loc?.longitude ?? null,
            };
        }).sort((a, b) => {
            if (a.distanceKm === null && b.distanceKm === null) return 0;
            if (a.distanceKm === null) return 1;
            if (b.distanceKm === null) return -1;
            return a.distanceKm - b.distanceKm;
        });

        const labs = await Lab.find({ status: 'Active' }).select('name city coordinates');

        const rankedLabs = labs.map((lab) => {
            const distance =
                lab.coordinates?.latitude != null && patientLat != null && patientLng != null
                    ? distanceKm(patientLat, patientLng, lab.coordinates.latitude, lab.coordinates.longitude)
                    : null;
            return {
                id: lab._id,
                name: lab.name,
                city: lab.city,
                distanceKm: distance,
                latitude: lab.coordinates?.latitude ?? null,
                longitude: lab.coordinates?.longitude ?? null,
            };
        }).sort((a, b) => {
            if (a.distanceKm === null && b.distanceKm === null) return 0;
            if (a.distanceKm === null) return 1;
            if (b.distanceKm === null) return -1;
            return a.distanceKm - b.distanceKm;
        });

        res.json({
            success: true,
            data: {
                patientLocation: patientLat != null ? { latitude: patientLat, longitude: patientLng } : null,
                nurses: rankedNurses,
                labs: rankedLabs,
            }
        });
    } catch (error) {
        console.error('Get assignment options error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Assign a nurse to a confirmed order (admin action - manual pick or "assign nearest")
router.post('/:orderId/assign-nurse', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { orderId } = req.params;
        const { nurseId } = req.body;
        const adminId = req.user.id;

        if (!nurseId) {
            return res.status(400).json({
                success: false,
                message: 'nurseId is required'
            });
        }

        const order = await Order.findById(orderId);
        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        if (order.status !== 'confirmed' || order.nurseId) {
            return res.status(400).json({
                success: false,
                message: 'Order is not available for nurse assignment'
            });
        }

        const nurse = await User.findOne({ _id: nurseId, role: 'nurse' });
        if (!nurse) {
            return res.status(404).json({
                success: false,
                message: 'Nurse not found'
            });
        }

        await order.adminAssignNurse(nurseId, adminId);
        const snapshot = pickNurseMapLocation(nurse);
        if (snapshot) {
            order.nurseMapLocation = snapshot;
            await order.save();
        }

        try {
            await fcmService.sendToUser(
                nurseId,
                'تم تعيينك لطلب جديد',
                `تم تعيينك من الإدارة لطلب رقم ${order.qrCode}`,
                {
                    type: 'nurse_assigned_by_admin',
                    orderId: order._id.toString(),
                }
            );
        } catch (fcmError) {
            console.error('FCM nurse assignment error:', fcmError);
        }

        try {
            await fcmService.sendToUser(
                order.patientId,
                'تم تحديد فني لأخذ العينة',
                `تم تعيين ${nurse.name || 'فني'} لطلبك وهو في طريقه إليك`,
                {
                    type: 'nurse_assigned',
                    orderId: order._id.toString(),
                    nurseName: nurse.name || 'Nurse',
                }
            );
        } catch (fcmError) {
            console.error('FCM patient notification error:', fcmError);
        }

        const updatedOrder = await Order.findById(orderId)
            .populate('patientId', 'name phone email')
            .populate('labId', 'name address phone city')
            .populate('nurseId', 'name phone');

        res.json({
            success: true,
            message: 'Nurse assigned successfully',
            data: { order: updatedOrder }
        });
    } catch (error) {
        console.error('Assign nurse error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Set a price quote on a prescription order (admin action) - patient must approve it
router.post('/:orderId/quote-prescription', auth.verifyToken, requireAdmin, ...uploadMedicinePhoto, async (req, res) => {
    try {
        const { orderId } = req.params;
        const adminId = req.user.id;
        const { medicineName, medicineType, price, notes } = req.body;

        // Lab-test prescriptions: a list of { name, price } read off the
        // prescription by the admin. Sent as a JSON string from the form.
        let tests = [];
        if (req.body.tests) {
            try {
                const parsed = typeof req.body.tests === 'string'
                    ? JSON.parse(req.body.tests)
                    : req.body.tests;
                if (Array.isArray(parsed)) {
                    tests = parsed
                        .map(t => ({
                            name: String(t.name || '').trim(),
                            price: parseFloat(t.price),
                        }))
                        .filter(t => t.name && !isNaN(t.price) && t.price >= 0);
                }
            } catch (_) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid tests payload'
                });
            }
        }

        // Total: explicit price wins, otherwise the sum of the test prices.
        const testsTotal = tests.reduce((sum, t) => sum + t.price, 0);
        const totalPrice = (price !== undefined && price !== '' && !isNaN(parseFloat(price)))
            ? parseFloat(price)
            : testsTotal;

        if (tests.length === 0 && (!totalPrice || totalPrice <= 0)) {
            return res.status(400).json({
                success: false,
                message: 'At least one test with a price (or a total price) is required'
            });
        }

        const order = await Order.findById(orderId);
        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        if (order.orderCategory !== 'prescription') {
            return res.status(400).json({
                success: false,
                message: 'This order is not a prescription order'
            });
        }

        if (order.status !== 'pending') {
            return res.status(400).json({
                success: false,
                message: 'A quote can only be set while the order is pending'
            });
        }

        await order.quotePrescription(adminId, {
            tests,
            medicineName,
            medicineType,
            price: totalPrice,
            imageUrl: req.file?.r2Url || null,
            notes,
        });

        try {
            await fcmService.sendToUser(
                order.patientId,
                'تحديد سعر طلبك',
                `تم تحديد سعر طلب الوصفة (${totalPrice} د.ع) - يرجى المراجعة والموافقة`,
                {
                    type: 'prescription_quoted',
                    orderId: order._id.toString(),
                }
            );
        } catch (fcmError) {
            console.error('FCM prescription quote error:', fcmError);
        }

        res.json({
            success: true,
            message: 'Price quote sent to patient',
            data: { order }
        });
    } catch (error) {
        console.error('Quote prescription error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Reject order (admin action)
router.post('/:orderId/reject', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { orderId } = req.params;
        const { reason } = req.body;
        const adminId = req.user.id;

        if (!reason) {
            return res.status(400).json({
                success: false,
                message: 'Rejection reason is required'
            });
        }

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Check if order can be rejected
        if (order.status !== 'pending') {
            return res.status(400).json({
                success: false,
                message: 'Order cannot be rejected at this stage'
            });
        }

        // Use the instance method to reject
        await order.rejectOrder(adminId, reason);

        res.json({
            success: true,
            message: 'Order rejected successfully',
            data: {
                order: order
            }
        });
    } catch (error) {
        console.error('Reject order error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get order statistics
router.get('/stats/overview', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { startDate, endDate } = req.query;

        const matchQuery = {};
        if (startDate || endDate) {
            matchQuery.createdAt = {};
            if (startDate) matchQuery.createdAt.$gte = new Date(startDate);
            if (endDate) matchQuery.createdAt.$lte = new Date(endDate);
        }

        const stats = await Order.aggregate([
            { $match: matchQuery },
            {
                $group: {
                    _id: null,
                    totalOrders: { $sum: 1 },
                    pendingOrders: {
                        $sum: { $cond: [{ $eq: ['$status', 'pending'] }, 1, 0] }
                    },
                    confirmedOrders: {
                        $sum: { $cond: [{ $eq: ['$status', 'confirmed'] }, 1, 0] }
                    },
                    inProgressOrders: {
                        $sum: { $cond: [{ $in: ['$status', ['nurse_assigned', 'sample_collected', 'at_lab']] }, 1, 0] }
                    },
                    completedOrders: {
                        $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] }
                    },
                    cancelledOrders: {
                        $sum: { $cond: [{ $eq: ['$status', 'cancelled'] }, 1, 0] }
                    },
                    totalRevenue: {
                        $sum: { $cond: [{ $eq: ['$payment.status', 'paid'] }, '$payment.amount', 0] }
                    }
                }
            }
        ]);

        res.json({
            success: true,
            data: {
                stats: stats[0] || {
                    totalOrders: 0,
                    pendingOrders: 0,
                    confirmedOrders: 0,
                    inProgressOrders: 0,
                    completedOrders: 0,
                    cancelledOrders: 0,
                    totalRevenue: 0
                }
            }
        });
    } catch (error) {
        console.error('Get stats error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get lab tests (for adding to order)
router.get('/lab/:labId/tests', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { labId } = req.params;

        const lab = await Lab.findById(labId);

        if (!lab) {
            return res.status(404).json({
                success: false,
                message: 'Lab not found'
            });
        }

        res.json({
            success: true,
            data: {
                tests: lab.tests || []
            }
        });
    } catch (error) {
        console.error('Get lab tests error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Add test to order
router.post('/:orderId/tests', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { orderId } = req.params;
        const { testId, testName, testCode, price, category } = req.body;

        if (!testId || !testName || !testCode || price === undefined) {
            return res.status(400).json({
                success: false,
                message: 'Missing required test fields'
            });
        }

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Check if test already exists in order
        const existingTest = order.tests.find(t => t.testId.toString() === testId.toString());
        if (existingTest) {
            return res.status(400).json({
                success: false,
                message: 'Test already exists in order'
            });
        }

        // Add test to order
        order.tests.push({
            testId,
            testName,
            testCode,
            price,
            category
        });

        // Recalculate pricing
        await order.calculateTotal();

        await order.save();

        const updatedOrder = await Order.findById(orderId)
            .populate('patientId', 'name email phone')
            .populate('labId', 'name address email phone city country')
            .populate('nurseId', 'name email phone')
            .populate('adminConfirmation.confirmedBy', 'name email')
            .populate('payment.collectedBy', 'name email')
            .populate('paymentCollected.collectedBy', 'name email')
            .populate('cancellation.cancelledBy', 'name email');

        res.json({
            success: true,
            message: 'Test added successfully',
            data: {
                order: updatedOrder
            }
        });
    } catch (error) {
        console.error('Add test error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Remove test from order
router.delete('/:orderId/tests/:testIndex', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { orderId, testIndex } = req.params;

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        if (testIndex < 0 || testIndex >= order.tests.length) {
            return res.status(400).json({
                success: false,
                message: 'Invalid test index'
            });
        }

        // Remove test
        const removedTest = order.tests.splice(testIndex, 1)[0];

        // Recalculate pricing
        await order.calculateTotal();

        await order.save();

        const updatedOrder = await Order.findById(orderId)
            .populate('patientId', 'name email phone')
            .populate('labId', 'name address email phone city country')
            .populate('nurseId', 'name email phone')
            .populate('adminConfirmation.confirmedBy', 'name email')
            .populate('payment.collectedBy', 'name email')
            .populate('paymentCollected.collectedBy', 'name email')
            .populate('cancellation.cancelledBy', 'name email');

        res.json({
            success: true,
            message: 'Test removed successfully',
            data: {
                order: updatedOrder,
                removedTest
            }
        });
    } catch (error) {
        console.error('Remove test error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Assign lab to an order (for nurse requests)
router.post('/:orderId/assign-lab', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { orderId } = req.params;
        const { labId } = req.body;

        if (!labId) {
            return res.status(400).json({
                success: false,
                message: 'Lab ID is required'
            });
        }

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Verify the lab exists
        const lab = await Lab.findById(labId);
        if (!lab) {
            return res.status(404).json({
                success: false,
                message: 'Lab not found'
            });
        }

        // Check if lab is changing - if so, clear the tests array
        const isLabChanging = order.labId && order.labId.toString() !== labId;

        // Assign the lab to the order
        order.labId = labId;
        
        // Clear tests if lab is changing (tests are lab-specific)
        if (isLabChanging) {
            order.tests = [];
            // Recalculate pricing
            order.pricing.subtotal = 0;
            order.pricing.total = order.pricing.urgencyFee - order.pricing.discount;
            order.payment.amount = order.pricing.total;
        }
        
        // Add to status history
        order.statusHistory.push({
            status: order.status,
            timestamp: new Date(),
            notes: isLabChanging ? `Lab changed to: ${lab.name}. Tests cleared.` : `Lab assigned: ${lab.name}`
        });

        await order.save();

        const updatedOrder = await Order.findById(orderId)
            .populate('patientId', 'name email phone')
            .populate('labId', 'name address email phone city country')
            .populate('nurseId', 'name email phone')
            .populate('adminConfirmation.confirmedBy', 'name email')
            .populate('payment.collectedBy', 'name email')
            .populate('paymentCollected.collectedBy', 'name email')
            .populate('cancellation.cancelledBy', 'name email');

        res.json({
            success: true,
            message: 'Lab assigned successfully',
            data: {
                order: updatedOrder
            }
        });
    } catch (error) {
        console.error('Assign lab error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get all labs (for lab selection dropdown)
router.get('/labs/all', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const labs = await Lab.find({ status: 'Active' })
            .select('name city address phone email')
            .sort({ name: 1 });

        res.json({
            success: true,
            data: {
                labs: labs
            }
        });
    } catch (error) {
        console.error('Get labs error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Search patients by phone or name (for admin order creation)
router.get('/patients/search', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const { q } = req.query;

        if (!q || q.length < 2) {
            return res.status(400).json({
                success: false,
                message: 'Search query must be at least 2 characters'
            });
        }

        const patients = await User.find({
            role: 'patient',
            status: 'active',
            $or: [
                { name: { $regex: q, $options: 'i' } },
                { phone: { $regex: q, $options: 'i' } },
                { email: { $regex: q, $options: 'i' } }
            ]
        })
        .select('name phone email city gender birthDate')
        .limit(10)
        .sort({ name: 1 });

        res.json({
            success: true,
            data: {
                patients
            }
        });
    } catch (error) {
        console.error('Patient search error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Create order by admin (for phone orders / walk-in patients)
router.post('/create', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const adminId = req.user.id;
        const {
            patientId,
            location,
            labId,
            tests,
            scheduledDate,
            timeSlot,
            patientNotes,
            beneficiary
        } = req.body;

        // Validation
        if (!patientId) {
            return res.status(400).json({
                success: false,
                message: 'Please select an existing patient account'
            });
        }

        if (!location || !location.address || !location.coordinates) {
            return res.status(400).json({
                success: false,
                message: 'Location with address and coordinates is required'
            });
        }

        if (!location.coordinates.latitude || !location.coordinates.longitude) {
            return res.status(400).json({
                success: false,
                message: 'Valid coordinates (latitude and longitude) are required'
            });
        }

        if (!labId) {
            return res.status(400).json({
                success: false,
                message: 'Lab selection is required'
            });
        }

        if (!tests || tests.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'At least one test is required'
            });
        }

        // The selected account owns the order and is the identity used by the mobile feed.
        const patient = await User.findById(patientId);
        if (!patient || patient.role !== 'patient' || patient.status !== 'active') {
            return res.status(404).json({
                success: false,
                message: 'Active patient account not found'
            });
        }

        // Verify lab exists
        const lab = await Lab.findById(labId);
        if (!lab) {
            return res.status(404).json({
                success: false,
                message: 'Lab not found'
            });
        }

        // Calculate pricing
        const subtotal = tests.reduce((sum, test) => sum + (test.price || 0), 0);
        const total = subtotal;

        // Create order
        const orderData = {
            patientId: patient._id,
            beneficiary: beneficiary ? {
                isForOtherPerson: beneficiary.isForOtherPerson || false,
                name: beneficiary.name,
                phone: beneficiary.phone,
                gender: beneficiary.gender,
                birthDate: beneficiary.birthDate ? new Date(beneficiary.birthDate) : null,
                relationship: beneficiary.relationship
            } : { isForOtherPerson: false },
            labId: labId,
            tests: tests.map(test => ({
                testId: test.testId,
                testName: test.testName,
                testCode: test.testCode,
                category: test.category,
                price: test.price
            })),
            qrCode: Order.generateQRCode(),
            location: {
                address: location.address,
                landmark: location.landmark || null,
                coordinates: {
                    latitude: parseFloat(location.coordinates.latitude),
                    longitude: parseFloat(location.coordinates.longitude)
                },
                buildingName: location.buildingName || null,
                floorNumber: location.floorNumber || null,
                apartmentNumber: location.apartmentNumber || null,
                instructions: location.instructions || null
            },
            scheduledDate: scheduledDate ? new Date(scheduledDate) : null,
            timeSlot: timeSlot || null,
            orderType: 'home_collection',
            status: 'confirmed',
            adminConfirmation: {
                confirmed: true,
                confirmedAt: new Date(),
                confirmedBy: adminId
            },
            payment: {
                status: 'pending',
                method: 'cash',
                amount: total,
                currency: 'IQD'
            },
            pricing: {
                subtotal: subtotal,
                urgencyFee: 0,
                discount: 0,
                total: total
            },
            notes: {
                patientNotes: patientNotes || '',
                adminNotes: 'Order created by admin via phone call'
            },
            statusHistory: [{
                status: 'confirmed',
                timestamp: new Date(),
                updatedBy: adminId,
                notes: 'Order created and confirmed by admin on behalf of patient'
            }]
        };

        const order = new Order(orderData);
        await order.save();

        // Populate and return
        const populatedOrder = await Order.findById(order._id)
            .populate('patientId', 'name email phone')
            .populate('labId', 'name address phone email city country');

        // Send Telegram notification (async, don't wait)
        telegramService.sendNewOrderNotification(populatedOrder).catch(err => {
            console.error('Failed to send Telegram notification:', err);
        });

        // This order starts as confirmed, so notify the patient here instead of
        // relying on the separate order-confirmation endpoint.
        try {
            await fcmService.sendToUser(
                patient._id,
                'تم إنشاء طلب جديد',
                'تم إنشاء طلب مختبر لك وتأكيده',
                {
                    type: 'order_accepted',
                    orderId: order._id.toString()
                }
            );
        } catch (fcmError) {
            console.error('FCM admin-created order notification error:', fcmError);
        }

        res.status(201).json({
            success: true,
            message: 'Order created successfully',
            data: {
                order: populatedOrder
            }
        });
    } catch (error) {
        console.error('Admin create order error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

module.exports = router;
