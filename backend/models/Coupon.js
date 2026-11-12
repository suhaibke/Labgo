const mongoose = require('mongoose');

// An admin-issued discount code, redeemable against lab-test orders
// (patient-facing checkout only - not shop orders, not lab-created).
const CouponSchema = new mongoose.Schema({
    code: {
        type: String,
        required: true,
        unique: true,
        uppercase: true,
        trim: true,
    },
    discountType: {
        type: String,
        enum: ['percentage', 'fixed'],
        required: true,
        default: 'percentage',
    },
    discountValue: {
        type: Number,
        required: true,
        min: 0,
    },
    minOrderAmount: {
        type: Number,
        default: 0,
    },
    maxDiscount: {
        type: Number,
        default: 0, // 0 = no cap (only relevant for percentage type)
    },
    usageLimit: {
        type: Number,
        default: null, // null = unlimited total redemptions
    },
    usageLimitPerUser: {
        type: Number,
        default: null, // null = unlimited redemptions per user
    },
    usedCount: {
        type: Number,
        default: 0,
    },
    startDate: {
        type: Date,
        default: Date.now,
    },
    endDate: {
        type: Date,
        default: null,
    },
    isActive: {
        type: Boolean,
        default: true,
    },
    createdBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },
    redeemedBy: [{
        userId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
        },
        orderId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Order',
        },
        redeemedAt: {
            type: Date,
            default: Date.now,
        },
    }],
}, { timestamps: true });

// Compute the discount amount for a given order subtotal - does not
// persist anything, callers are responsible for validating eligibility
// (active, date range, usage limits, minOrderAmount) before calling this.
CouponSchema.methods.calculateDiscount = function (orderTotal) {
    let discount;
    if (this.discountType === 'percentage') {
        discount = Math.round((orderTotal * this.discountValue) / 100);
        if (this.maxDiscount > 0 && discount > this.maxDiscount) {
            discount = this.maxDiscount;
        }
    } else {
        discount = this.discountValue;
    }
    return Math.min(discount, orderTotal);
};

module.exports = mongoose.model('Coupon', CouponSchema);
