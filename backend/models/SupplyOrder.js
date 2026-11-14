// A lab's order for supplies (reagents, tubes, kits) sent to a supplier.
// Created from the web dashboard or the lab app; printed / shared as a PDF.
const mongoose = require('mongoose');

const itemSchema = new mongoose.Schema({
    name: { type: String, required: true, trim: true, maxlength: 160 },
    qty: { type: String, default: '', trim: true, maxlength: 20 },
    unit: { type: String, default: '', trim: true, maxlength: 20 },
}, { _id: false });

const supplyOrderSchema = new mongoose.Schema({
    labId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lab', required: true, index: true },
    no: { type: Number, required: true },
    supplier: { type: String, default: '', trim: true, maxlength: 160 },
    supplierPhone: { type: String, default: '', trim: true, maxlength: 40 },
    neededBy: { type: String, default: '', trim: true, maxlength: 20 },
    notes: { type: String, default: '', trim: true, maxlength: 1000 },
    items: { type: [itemSchema], default: [] },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
}, { timestamps: true });

supplyOrderSchema.index({ labId: 1, no: 1 }, { unique: true });

module.exports = mongoose.model('SupplyOrder', supplyOrderSchema);
