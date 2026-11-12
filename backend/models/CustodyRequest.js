const mongoose = require('mongoose');
const crypto = require('crypto');

function generateReturnCode() {
    return 'RET-' + crypto.randomBytes(5).toString('hex').toUpperCase();
}

// Tracks one full request-to-return cycle for a custody item:
// pending -> approved -> delivered -> return_requested -> returned
// (or -> rejected at the approval step)
const CustodyRequestSchema = new mongoose.Schema({
    nurseId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true,
    },
    itemName: {
        // What the nurse asked for, captured at request time (e.g. "جهاز قياس ضغط الدم")
        type: String,
        required: true,
        trim: true,
    },
    itemId: {
        // A specific physical unit, assigned by the admin at approval time
        type: mongoose.Schema.Types.ObjectId,
        ref: 'CustodyItem',
        default: null,
    },
    requestedDurationDays: {
        type: Number,
        required: true,
        min: 1,
    },
    expectedReturnDate: {
        type: Date,
        default: null,
    },
    status: {
        type: String,
        enum: ['pending', 'approved', 'rejected', 'delivered', 'return_requested', 'returned'],
        default: 'pending',
    },
    requestedAt: {
        type: Date,
        default: Date.now,
    },
    reviewedAt: Date,
    reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    rejectionReason: String,
    deliveredAt: Date,
    deliveredBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    returnCode: {
        // Generated when the nurse initiates a return; the admin scans this
        // (shown on the nurse's phone) to confirm the item is physically back.
        type: String,
        default: null,
    },
    returnRequestedAt: Date,
    returnConfirmedAt: Date,
    returnConfirmedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    notes: String,
}, { timestamps: true });

CustodyRequestSchema.methods.approve = function (adminId, itemId) {
    this.status = 'approved';
    this.itemId = itemId;
    this.reviewedAt = new Date();
    this.reviewedBy = adminId;
    this.expectedReturnDate = new Date(Date.now() + this.requestedDurationDays * 24 * 60 * 60 * 1000);
    return this.save();
};

CustodyRequestSchema.methods.reject = function (adminId, reason) {
    this.status = 'rejected';
    this.reviewedAt = new Date();
    this.reviewedBy = adminId;
    this.rejectionReason = reason;
    return this.save();
};

CustodyRequestSchema.methods.markDelivered = function (adminId) {
    this.status = 'delivered';
    this.deliveredAt = new Date();
    this.deliveredBy = adminId;
    return this.save();
};

CustodyRequestSchema.methods.initiateReturn = function () {
    this.status = 'return_requested';
    this.returnCode = generateReturnCode();
    this.returnRequestedAt = new Date();
    return this.save();
};

CustodyRequestSchema.methods.confirmReturn = function (adminId) {
    this.status = 'returned';
    this.returnConfirmedAt = new Date();
    this.returnConfirmedBy = adminId;
    return this.save();
};

module.exports = mongoose.model('CustodyRequest', CustodyRequestSchema);
