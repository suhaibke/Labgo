const express = require('express');
const router = express.Router();
const path = require('path');
const User = require('../models/User');
const Lab = require('../models/Lab');
const Order = require('../models/Order');
const Coupon = require('../models/Coupon');
const auth = require('../middleware/auth');
const telegramService = require('../services/telegramService');
const { r2SingleUpload } = require('../middleware/r2Upload');
const r2Service = require('../services/r2Service');
const { attachNurseMapLocation } = require('../helpers/nurseLocation');

// R2 upload middleware for prescription uploads
const uploadPrescription = r2SingleUpload('prescriptions', 'prescription', 'prescription-');

// Validates a coupon code against an order subtotal and the requesting
// user's own redemption history. Returns { coupon, discount } on success,
// or { error } on failure - never persists anything.
async function resolveCoupon(code, orderTotal, userId) {
    if (!code) return { error: null, coupon: null, discount: 0 };

    const coupon = await Coupon.findOne({ code: String(code).trim().toUpperCase() });
    if (!coupon) {
        return { error: 'Invalid coupon code' };
    }
    if (!coupon.isActive) {
        return { error: 'This coupon is no longer active' };
    }
    const now = new Date();
    if (coupon.startDate && new Date(coupon.startDate) > now) {
        return { error: 'This coupon is not active yet' };
    }
    if (coupon.endDate && new Date(coupon.endDate) < now) {
        return { error: 'This coupon has expired' };
    }
    if (coupon.usageLimit && coupon.usedCount >= coupon.usageLimit) {
        return { error: 'This coupon has reached its usage limit' };
    }
    if (coupon.usageLimitPerUser) {
        const userRedemptions = coupon.redeemedBy.filter(
            (r) => r.userId && r.userId.toString() === String(userId)
        ).length;
        if (userRedemptions >= coupon.usageLimitPerUser) {
            return { error: 'You have already used this coupon the maximum number of times' };
        }
    }
    if (orderTotal < coupon.minOrderAmount) {
        return { error: `This coupon requires a minimum order of ${coupon.minOrderAmount} IQD` };
    }

    const discount = coupon.calculateDiscount(orderTotal);
    return { error: null, coupon, discount };
}

// Helper function to get order by ID with populated fields
async function getOrderById(orderId, userId, role) {
    const order = await Order.findById(orderId)
        .populate('patientId', 'name email phone profilePicture gender birthDate')
        .populate('labId', 'name address contact averageRating totalReviews coordinates')
        .populate('nurseId', 'name email phone averageRating totalRatings currentLocation defaultLocation profilePicture');

    if (!order) {
        return null;
    }

    // Check access permissions
    if (role === 'patient' && order.patientId._id.toString() !== userId.toString()) {
        return null;
    }
    if (role === 'lab' && order.labId._id.toString() !== userId.toString()) {
        return null;
    }
    if (role === 'nurse' && order.nurseId?.toString() !== userId.toString()) {
        return null;
    }

    return order;
}

// Create order from cart
// Preview a coupon's discount before placing the order (no side effects).
router.post('/validate-coupon', auth.verifyToken, async (req, res) => {
    try {
        const { code, orderTotal } = req.body;
        if (!code) {
            return res.status(400).json({ success: false, message: 'Coupon code is required' });
        }

        const total = Number(orderTotal) || 0;
        const result = await resolveCoupon(code, total, req.user.id);

        if (result.error) {
            return res.status(400).json({ success: false, message: result.error });
        }

        res.json({
            success: true,
            data: {
                discountAmount: result.discount,
                newTotal: total - result.discount,
            },
        });
    } catch (error) {
        console.error('Validate coupon error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

router.post('/create', auth.verifyToken, ...uploadPrescription, async (req, res) => {
    try {
        const userId = req.user.id;
        const { location, scheduledDate, timeSlot, orderType, patientNotes, labId, prescriptionOnly, beneficiary, couponCode } = req.body;

        // Validate required fields
        if (!location) {
            return res.status(400).json({
                success: false,
                message: 'Location is required'
            });
        }

        let parsedLocation;
        try {
            parsedLocation = typeof location === 'string' ? JSON.parse(location) : location;
        } catch (e) {
            return res.status(400).json({
                success: false,
                message: 'Invalid location format'
            });
        }

        if (!parsedLocation.address || !parsedLocation.coordinates) {
            return res.status(400).json({
                success: false,
                message: 'Address and coordinates are required'
            });
        }

        // Get user with cart
        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Handle prescription image - required for prescription-only orders
        let prescriptionImageUrl = null;
        const isPrescriptionOnly = prescriptionOnly === 'true' || prescriptionOnly === true;

        if (req.file && req.file.r2Url) {
            prescriptionImageUrl = req.file.r2Url;
        } else if (user.cart.prescriptionImage) {
            prescriptionImageUrl = user.cart.prescriptionImage;
        }

        // For prescription-only orders, validate labId and prescription
        if (isPrescriptionOnly) {
            if (!labId) {
                return res.status(400).json({
                    success: false,
                    message: 'Lab ID is required for prescription orders'
                });
            }
            if (!prescriptionImageUrl) {
                return res.status(400).json({
                    success: false,
                    message: 'Prescription image is required for prescription orders'
                });
            }
        } else {
            // For normal orders, check if cart has items
            if (!user.cart || !user.cart.labId || user.cart.tests.length === 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Cart is empty. Add tests to cart first'
                });
            }
        }

        // Get lab details - from cart or from prescription-only request
        const targetLabId = isPrescriptionOnly ? labId : user.cart.labId;
        const lab = await Lab.findById(targetLabId);
        if (!lab) {
            return res.status(404).json({
                success: false,
                message: 'Lab not found'
            });
        }

        // Parse time slot if provided
        let parsedTimeSlot = null;
        if (timeSlot) {
            try {
                parsedTimeSlot = typeof timeSlot === 'string' ? JSON.parse(timeSlot) : timeSlot;
            } catch (e) {
                // Ignore invalid time slot
            }
        }

        // Parse beneficiary data if provided
        let parsedBeneficiary = null;
        if (beneficiary) {
            try {
                parsedBeneficiary = typeof beneficiary === 'string' ? JSON.parse(beneficiary) : beneficiary;
            } catch (e) {
                // Ignore invalid beneficiary format
            }
        }

        // Calculate pricing - no fees for prescription-only orders (admin will determine price)
        const subtotal = isPrescriptionOnly ? 0 : user.cart.totalPrice;

        // Re-validate any coupon from scratch server-side - never trust a
        // client-computed discount amount.
        let appliedCoupon = null;
        let discountAmount = 0;
        if (!isPrescriptionOnly && couponCode) {
            const couponResult = await resolveCoupon(couponCode, subtotal, userId);
            if (couponResult.error) {
                return res.status(400).json({ success: false, message: couponResult.error });
            }
            appliedCoupon = couponResult.coupon;
            discountAmount = couponResult.discount;
        }

        const total = subtotal - discountAmount;

        // Create order - handle both prescription-only and normal orders
        const orderData = {
            patientId: userId,
            // Beneficiary info (if ordering for another person)
            beneficiary: parsedBeneficiary ? {
                isForOtherPerson: true,
                name: parsedBeneficiary.name,
                phone: parsedBeneficiary.phone,
                gender: parsedBeneficiary.gender,
                birthDate: parsedBeneficiary.birthDate ? new Date(parsedBeneficiary.birthDate) : null,
                relationship: parsedBeneficiary.relationship,
            } : { isForOtherPerson: false },
            labId: targetLabId,
            tests: isPrescriptionOnly ? [] : user.cart.tests.map(test => ({
                testId: test.testId,
                testName: test.testName,
                testCode: test.testCode,
                category: test.category,
                price: test.price,
                originalPrice: test.originalPrice || test.price, // Store original price for reference
            })),
            prescriptionImage: prescriptionImageUrl,
            qrCode: Order.generateQRCode(),
            location: {
                address: parsedLocation.address,
                landmark: parsedLocation.landmark,
                coordinates: {
                    latitude: parsedLocation.coordinates.latitude,
                    longitude: parsedLocation.coordinates.longitude
                },
                buildingName: parsedLocation.buildingName,
                floorNumber: parsedLocation.floorNumber,
                apartmentNumber: parsedLocation.apartmentNumber,
                instructions: parsedLocation.instructions,
                phone: parsedLocation.phone,
            },
            scheduledDate: scheduledDate ? new Date(scheduledDate) : null,
            timeSlot: parsedTimeSlot,
            orderType: orderType || 'home_collection',
            status: 'pending',
            orderCategory: isPrescriptionOnly ? 'prescription' : 'test',
            prescriptionType: isPrescriptionOnly ? 'lab_test' : undefined,
            payment: {
                status: 'pending',
                method: 'cash',
                amount: total,
                currency: 'IQD'
            },
            pricing: {
                subtotal: subtotal,
                discount: discountAmount,
                total: total
            },
            couponCode: appliedCoupon ? appliedCoupon.code : null,
            notes: {
                patientNotes: patientNotes
            },
            statusHistory: [{
                status: 'pending',
                timestamp: new Date(),
                notes: isPrescriptionOnly
                    ? 'Prescription-only order placed, awaiting admin review'
                    : 'Order placed, awaiting admin confirmation'
            }]
        };

        const order = new Order(orderData);
        await order.save();

        // Record coupon redemption now that the order it applies to exists.
        if (appliedCoupon) {
            appliedCoupon.usedCount += 1;
            appliedCoupon.redeemedBy.push({ userId, orderId: order._id, redeemedAt: new Date() });
            await appliedCoupon.save();
        }

        // Clear user's cart only for non-prescription orders after successful order creation
        if (!isPrescriptionOnly) {
            await user.clearCart();
        }

        // Send Telegram notification for new order
        // Populate order with related data before sending notification
        const populatedOrder = await Order.findById(order._id)
            .populate('patientId', 'name email phone')
            .populate('labId', 'name address phone email city country');

        // Send notification asynchronously (don't wait for it)
        telegramService.sendNewOrderNotification(populatedOrder).catch(err => {
            console.error('Failed to send Telegram notification:', err);
        });

        res.status(201).json({
            success: true,
            message: 'Order created successfully. Waiting for admin confirmation.',
            data: {
                order: order
            }
        });
    } catch (error) {
        console.error('Create order error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

// Create nurse request (without pre-selecting a lab)
// Admin will assign the lab and tests later
router.post('/nurse-request', auth.verifyToken, ...uploadPrescription, async (req, res) => {
    try {
        const userId = req.user.id;
        const { location, scheduledDate, timeSlot, beneficiary, patientNotes } = req.body;
        // Medicine prescriptions are delivery orders: the location is a
        // delivery address, the admin prices the medicine, and patient
        // approval confirms the order directly (no nurse/lab lifecycle).
        const isMedicine = req.body.medicine === true || req.body.medicine === 'true';

        // Validate required fields
        if (!location) {
            return res.status(400).json({
                success: false,
                message: 'Location is required'
            });
        }

        let parsedLocation;
        try {
            parsedLocation = typeof location === 'string' ? JSON.parse(location) : location;
        } catch (e) {
            return res.status(400).json({
                success: false,
                message: 'Invalid location format'
            });
        }

        if (!parsedLocation.address || !parsedLocation.coordinates) {
            return res.status(400).json({
                success: false,
                message: 'Address and coordinates are required'
            });
        }

        // Get user
        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Handle prescription image - required for nurse requests
        let prescriptionImageUrl = null;
        if (req.file && req.file.r2Url) {
            prescriptionImageUrl = req.file.r2Url;
        }

        if (!prescriptionImageUrl) {
            return res.status(400).json({
                success: false,
                message: 'Prescription image is required for nurse requests'
            });
        }

        // Parse time slot if provided
        let parsedTimeSlot = null;
        if (timeSlot) {
            try {
                parsedTimeSlot = typeof timeSlot === 'string' ? JSON.parse(timeSlot) : timeSlot;
            } catch (e) {
                // Ignore invalid time slot
            }
        }

        // Parse beneficiary data if provided
        let parsedBeneficiary = null;
        if (beneficiary) {
            try {
                parsedBeneficiary = typeof beneficiary === 'string' ? JSON.parse(beneficiary) : beneficiary;
            } catch (e) {
                // Ignore invalid beneficiary format
            }
        }

        // Create nurse request order (no lab, no tests, no price yet - admin will set these)
        const orderData = {
            patientId: userId,
            beneficiary: parsedBeneficiary ? {
                isForOtherPerson: true,
                name: parsedBeneficiary.name,
                phone: parsedBeneficiary.phone,
                gender: parsedBeneficiary.gender,
                birthDate: parsedBeneficiary.birthDate ? new Date(parsedBeneficiary.birthDate) : null,
                relationship: parsedBeneficiary.relationship,
            } : { isForOtherPerson: false },
            labId: null, // No lab selected - admin will assign
            isNurseRequest: !isMedicine, // Medicine orders are deliveries, not nurse visits
            prescriptionType: isMedicine ? 'medicine' : 'lab_test',
            tests: [], // No tests yet - admin will add after assigning lab
            prescriptionImage: prescriptionImageUrl,
            qrCode: Order.generateQRCode(),
            location: {
                address: parsedLocation.address,
                landmark: parsedLocation.landmark,
                coordinates: {
                    latitude: parsedLocation.coordinates.latitude,
                    longitude: parsedLocation.coordinates.longitude
                },
                buildingName: parsedLocation.buildingName,
                floorNumber: parsedLocation.floorNumber,
                apartmentNumber: parsedLocation.apartmentNumber,
                instructions: parsedLocation.instructions,
                phone: parsedLocation.phone,
            },
            scheduledDate: isMedicine ? null : (scheduledDate ? new Date(scheduledDate) : null),
            timeSlot: isMedicine ? null : parsedTimeSlot,
            orderType: 'home_collection',
            status: 'pending',
            orderCategory: 'prescription',
            patientNotes: patientNotes || undefined,
            payment: {
                status: 'pending',
                method: 'cash',
                amount: 0, // Will be set by admin after selecting lab and tests
                currency: 'IQD'
            },
            pricing: {
                subtotal: 0, // Will be set by admin
                discount: 0,
                total: 0 // Will be set by admin
            },
            statusHistory: [{
                status: 'pending',
                timestamp: new Date(),
                notes: isMedicine
                    ? 'Medicine prescription placed, awaiting admin to set the price'
                    : 'Nurse request placed, awaiting admin to assign lab and tests'
            }]
        };

        const order = new Order(orderData);
        await order.save();

        // Populate order with patient data for notification
        const populatedOrder = await Order.findById(order._id)
            .populate('patientId', 'name email phone');

        // Send Telegram notification for new nurse request
        telegramService.sendNewOrderNotification(populatedOrder).catch(err => {
            console.error('Failed to send Telegram notification:', err);
        });

        res.status(201).json({
            success: true,
            message: isMedicine
                ? 'Medicine request created successfully. You will be notified with the price for approval.'
                : 'Nurse request created successfully. Admin will review and assign a lab.',
            data: {
                order: order
            }
        });
    } catch (error) {
        console.error('Create nurse request error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

// Get all orders for the current patient
router.get('/my-orders', auth.verifyToken, async (req, res) => {
    try {
        const userId = req.user.id;
        const { status, page = 1, limit = 20 } = req.query;

        const query = { patientId: userId };
        if (status) {
            query.status = status;
        }

        const orders = await Order.find(query)
            .populate('patientId', 'name email phone gender birthDate profilePicture')
            .populate('labId', 'name address contact averageRating totalReviews')
            .populate('nurseId', 'name phone averageRating totalRatings currentLocation defaultLocation profilePicture')
            .sort({ createdAt: -1 })
            .limit(parseInt(limit))
            .skip((parseInt(page) - 1) * parseInt(limit));

        const total = await Order.countDocuments(query);

        res.json({
            success: true,
            data: {
                orders: orders.map(attachNurseMapLocation),
                total: total,
                page: parseInt(page),
                pages: Math.ceil(total / parseInt(limit))
            }
        });
    } catch (error) {
        console.error('Get patient orders error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Get order by ID
router.get('/:orderId', auth.verifyToken, async (req, res) => {
    try {
        const { orderId } = req.params;
        const userId = req.user.id;
        const role = req.user.role;

        const order = await getOrderById(orderId, userId, role);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        res.json({
            success: true,
            data: {
                order: attachNurseMapLocation(order)
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

// Patient responds to a prescription price quote (approve or reject)
router.post('/:orderId/respond-to-quote', auth.verifyToken, async (req, res) => {
    try {
        const { orderId } = req.params;
        const { approved } = req.body;
        const userId = req.user.id;

        if (typeof approved !== 'boolean') {
            return res.status(400).json({
                success: false,
                message: 'approved (true/false) is required'
            });
        }

        const order = await Order.findById(orderId);
        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        if (order.patientId.toString() !== userId.toString()) {
            return res.status(403).json({
                success: false,
                message: 'Access denied'
            });
        }

        if (order.status !== 'quoted') {
            return res.status(400).json({
                success: false,
                message: 'This order has no pending price quote'
            });
        }

        await order.respondToPrescriptionQuote(userId, approved);

        const updatedOrder = await Order.findById(orderId)
            .populate('patientId', 'name email phone')
            .populate('labId', 'name address contact');

        res.json({
            success: true,
            message: approved ? 'Quote approved' : 'Quote rejected',
            data: { order: updatedOrder }
        });
    } catch (error) {
        console.error('Respond to quote error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Cancel order
router.post('/:orderId/cancel', auth.verifyToken, async (req, res) => {
    try {
        const { orderId } = req.params;
        const { reason } = req.body;
        const userId = req.user.id;
        const role = req.user.role;

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Check permissions
        if (role === 'patient' && order.patientId.toString() !== userId.toString()) {
            return res.status(403).json({
                success: false,
                message: 'Access denied'
            });
        }

        // Can only cancel pending, quoted, or confirmed orders
        if (!['pending', 'quoted', 'confirmed'].includes(order.status)) {
            return res.status(400).json({
                success: false,
                message: 'Order cannot be cancelled at this stage'
            });
        }

        // Cancel order
        order.status = 'cancelled';
        order.cancellation = {
            reason: reason || 'No reason provided',
            cancelledBy: userId,
            cancelledAt: new Date()
        };
        order.statusHistory.push({
            status: 'cancelled',
            timestamp: new Date(),
            updatedBy: userId,
            notes: reason || 'Order cancelled'
        });

        await order.save();

        res.json({
            success: true,
            message: 'Order cancelled successfully',
            data: {
                order: order
            }
        });
    } catch (error) {
        console.error('Cancel order error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Rate order
router.post('/:orderId/rate', auth.verifyToken, async (req, res) => {
    try {
        const { orderId } = req.params;
        const { labRating, nurseRating, serviceRating, feedback, labRatingReason, nurseRatingReason } = req.body;
        const userId = req.user.id;

        const order = await Order.findById(orderId);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found'
            });
        }

        // Check permissions
        if (order.patientId.toString() !== userId.toString()) {
            return res.status(403).json({
                success: false,
                message: 'Access denied'
            });
        }

        // Can only rate completed orders
        if (order.status !== 'completed') {
            return res.status(400).json({
                success: false,
                message: 'Order must be completed before rating'
            });
        }

        // Check if already rated
        if (order.rating?.ratedAt) {
            return res.status(400).json({
                success: false,
                message: 'Order already rated'
            });
        }

        // Validate: low ratings (1-3) require a reason
        if (labRating && labRating <= 3 && !labRatingReason) {
            return res.status(400).json({
                success: false,
                message: 'Please provide a reason for the low lab rating'
            });
        }

        if (nurseRating && nurseRating <= 3 && !nurseRatingReason) {
            return res.status(400).json({
                success: false,
                message: 'Please provide a reason for the low nurse rating'
            });
        }

        // Update rating
        order.rating = {
            labRating: labRating,
            labRatingReason: labRatingReason || null,
            nurseRating: nurseRating,
            nurseRatingReason: nurseRatingReason || null,
            serviceRating: serviceRating,
            feedback: feedback,
            ratedAt: new Date()
        };

        await order.save();

        // Update lab's average rating
        if (labRating && order.labId) {
            await updateLabAverageRating(order.labId);
        }

        // Update nurse's average rating
        if (nurseRating && order.nurseId) {
            await updateNurseAverageRating(order.nurseId);
        }

        res.json({
            success: true,
            message: 'Rating submitted successfully'
        });
    } catch (error) {
        console.error('Rate order error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
});

// Helper function to update lab's average rating
async function updateLabAverageRating(labId) {
    try {
        const result = await Order.aggregate([
            {
                $match: {
                    labId: labId,
                    'rating.labRating': { $exists: true, $ne: null },
                    'rating.ratedAt': { $exists: true }
                }
            },
            {
                $group: {
                    _id: null,
                    averageRating: { $avg: '$rating.labRating' },
                    totalReviews: { $sum: 1 }
                }
            }
        ]);

        if (result.length > 0) {
            await Lab.findByIdAndUpdate(labId, {
                averageRating: Math.round(result[0].averageRating * 10) / 10, // Round to 1 decimal
                totalReviews: result[0].totalReviews
            });
        }
    } catch (error) {
        console.error('Error updating lab average rating:', error);
    }
}

// Helper function to update nurse's average rating
async function updateNurseAverageRating(nurseId) {
    try {
        const result = await Order.aggregate([
            {
                $match: {
                    nurseId: nurseId,
                    'rating.nurseRating': { $exists: true, $ne: null },
                    'rating.ratedAt': { $exists: true }
                }
            },
            {
                $group: {
                    _id: null,
                    averageRating: { $avg: '$rating.nurseRating' },
                    totalReviews: { $sum: 1 }
                }
            }
        ]);

        if (result.length > 0) {
            await User.findByIdAndUpdate(nurseId, {
                averageRating: Math.round(result[0].averageRating * 10) / 10, // Round to 1 decimal
                totalRatings: result[0].totalReviews
            });
        }
    } catch (error) {
        console.error('Error updating nurse average rating:', error);
    }
}

module.exports = router;
