const mongoose = require('mongoose');
const crypto = require('crypto');

function generateCode() {
    return 'CUST-' + crypto.randomBytes(5).toString('hex').toUpperCase();
}

// One document per physical unit - e.g. 3 blood pressure devices are 3
// separate documents, each with its own unique barcode, so each can be
// requested/delivered/returned independently.
const CustodyItemSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
        trim: true,
    },
    category: {
        type: String,
        enum: ['equipment', 'consumable', 'sensitive', 'financial'],
        required: true,
    },
    code: {
        // Auto-generated, unique per physical unit, encoded into its printed barcode/QR
        type: String,
        required: true,
        unique: true,
        default: generateCode,
    },
    serialNumber: {
        type: String,
        trim: true,
    },
    value: {
        // Monetary value in IQD
        type: Number,
        default: 0,
    },
    status: {
        type: String,
        enum: ['available', 'in_use', 'damaged', 'missing', 'needs_maintenance'],
        default: 'available',
    },
    receivedFrom: {
        type: String,
        trim: true,
    },
    notes: {
        type: String,
        trim: true,
    },
    currentHolder: {
        // Denormalized for quick lookup; the source of truth for the full
        // lifecycle of a hand-off is the linked CustodyRequest.
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        default: null,
        index: true,
    },
}, { timestamps: true });

module.exports = mongoose.model('CustodyItem', CustodyItemSchema);
