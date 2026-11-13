const mongoose = require('mongoose');

// A sample sent out to a lab outside the platform to run a test this lab
// can't do itself. Deliberately NOT embedded on Order: a transfer can be
// logged for a real system order (orderId set, patient/test fields snapshot
// from that order) OR entered entirely by hand for a sample that was never
// placed as an order here at all (orderId null, every field typed by staff).
const ExternalTransferSchema = new mongoose.Schema({
    labId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Lab',
        required: true,
        index: true,
    },
    // Present only when this transfer tracks a real system order.
    orderId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Order',
        default: null,
        index: true,
    },

    sampleCode: {
        type: String,
        required: true,
        trim: true,
    },

    // Patient snapshot - copied from the order at creation time, or typed
    // by hand when there's no order. Never re-read from the order later,
    // so the transfer record stays accurate even if the order changes.
    patientName: { type: String, required: true, trim: true, maxlength: 200 },
    patientPhone: { type: String, trim: true, maxlength: 50 },
    patientGender: { type: String, enum: ['male', 'female', null], default: null },
    patientAge: { type: Number, min: 0, max: 120, default: null },

    // Structured tests (from an order) or a free-text description (manual).
    tests: [{
        testId: { type: mongoose.Schema.Types.ObjectId },
        testName: { type: String, trim: true },
        _id: false,
    }],
    testsDescription: { type: String, trim: true, maxlength: 500 },

    externalLab: {
        name: { type: String, required: true, trim: true, maxlength: 200 },
        contactName: { type: String, trim: true, maxlength: 200 },
        phone: { type: String, trim: true, maxlength: 50 },
        address: { type: String, trim: true, maxlength: 500 },
    },

    status: {
        type: String,
        enum: ['sent', 'completed'],
        default: 'sent',
        required: true,
    },
    sentAt: { type: Date, required: true, default: Date.now },
    expectedResultAt: Date,
    referenceNumber: { type: String, trim: true, maxlength: 100 },
    notes: { type: String, trim: true, maxlength: 1000 },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    completedAt: Date,
    resultFileUrl: String,
    // 'lab' = uploaded by this lab; 'external_link' = uploaded by the receiving
    // lab through the QR code on the label (reviewed before going to the patient).
    resultSource: { type: String, enum: ['lab', 'external_link', 'receiving_lab'], default: 'lab' },

    // ---- lab-to-lab on LabGo: the receiving lab is registered ----
    toLabId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lab', default: null, index: true },
    // Agreed price (IQD), by default the receiving lab's B2B prices; editable.
    price: { type: Number, min: 0, default: null },
    priceSource: { type: String, enum: ['b2b', 'manual', null], default: null },
    receivedAt: Date,
    receivedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    // Results entered by the receiving lab (same shape as Order.results).
    receiverResults: {
        values: [{
            _id: false,
            testName: { type: String, trim: true },
            value: { type: String, trim: true, default: '' },
            unit: { type: String, trim: true, default: '' },
            min: { type: Number, default: null },
            max: { type: Number, default: null },
            normalText: { type: String, trim: true, default: '' },
            flag: { type: String, enum: ['', 'normal', 'low', 'high'], default: '' },
        }],
        comment: { type: String, trim: true, default: '' },
        entryStatus: { type: String, enum: ['none', 'draft', 'approved'], default: 'none' },
        enteredAt: Date,
        approvedAt: Date,
        approvedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    },
    externalUpload: {
        uploadedAt: Date,
        uploaderName: { type: String, trim: true, maxlength: 120 },
        note: { type: String, trim: true, maxlength: 1000 },
    },
    // When an external result was sent on to the patient's order.
    forwardedAt: Date,
}, { timestamps: true });

ExternalTransferSchema.index({ labId: 1, sentAt: -1 });

ExternalTransferSchema.statics.generateSampleCode = function () {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substring(2, 8);
    return `EXT-${timestamp}-${random}`.toUpperCase();
};

module.exports = mongoose.model('ExternalTransfer', ExternalTransferSchema);
