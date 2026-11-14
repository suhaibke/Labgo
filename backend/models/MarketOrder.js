// An order between two labs in the store: buying a product, or asking to buy
// a lab that is for sale ("interest"). The selling lab moves it through the
// steps; both labs are notified on every change.
const mongoose = require('mongoose');

const STATUSES = ['new', 'preparing', 'shipped', 'delivered', 'cancelled'];

const MarketOrderSchema = new mongoose.Schema({
    orderNo: { type: Number, required: true, unique: true },
    listingId: { type: mongoose.Schema.Types.ObjectId, ref: 'MarketListing', required: true, index: true },
    kind: { type: String, enum: ['purchase', 'interest'], default: 'purchase' },
    buyerLabId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lab', required: true, index: true },
    buyerLabName: { type: String, default: '' },
    sellerLabId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lab', required: true, index: true },
    sellerLabName: { type: String, default: '' },
    title: { type: String, default: '' },
    code: { type: String, default: '' },
    image: { type: String, default: '' },
    quantity: { type: Number, min: 1, default: 1 },
    unitPrice: { type: Number, min: 0, default: 0 },
    total: { type: Number, min: 0, default: 0 },
    address: { type: String, trim: true, maxlength: 300, default: '' },
    phone: { type: String, trim: true, maxlength: 40, default: '' },
    note: { type: String, trim: true, maxlength: 600, default: '' },
    status: { type: String, enum: STATUSES, default: 'new', index: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
}, { timestamps: true });

const MarketOrder = mongoose.model('MarketOrder', MarketOrderSchema);
MarketOrder.STATUSES = STATUSES;
module.exports = MarketOrder;
