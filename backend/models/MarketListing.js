const mongoose = require('mongoose');

// The labs' marketplace: products / devices for sale, auctions (a device or a
// whole lab) and labs for sale. Nothing is shown to other labs until the
// LabGo admin approves it.
const KINDS = ['product', 'auction', 'lab_sale', 'lab_auction'];

const BidSchema = new mongoose.Schema({
    labId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lab' },
    labName: String,
    amount: Number,
    at: { type: Date, default: Date.now },
}, { _id: false });

const MarketListingSchema = new mongoose.Schema({
    labId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lab', required: true, index: true },
    kind: { type: String, enum: KINDS, required: true, index: true },
    title: { type: String, trim: true, maxlength: 160, required: true },
    description: { type: String, trim: true, maxlength: 3000, default: '' },
    category: { type: String, trim: true, maxlength: 40, default: '' }, // Device | Reagent | Consumable
    condition: { type: String, enum: ['New', 'Used', ''], default: '' },
    code: { type: String, trim: true, maxlength: 40, default: '' },
    price: { type: Number, min: 0, default: 0 },          // sale price, or the starting bid
    stock: { type: Number, min: 0, default: 0 },
    unit: { type: String, trim: true, maxlength: 20, default: '' },
    location: { type: String, trim: true, maxlength: 200, default: '' },
    area: { type: String, trim: true, maxlength: 40, default: '' },
    equipment: { type: String, trim: true, maxlength: 600, default: '' },
    images: [{ type: String }],
    approvalStatus: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending', index: true },
    rejectReason: { type: String, trim: true, maxlength: 300, default: '' },
    reviewedAt: Date,
    // auctions
    endsAt: Date,
    durationDays: { type: Number, default: 3 },
    bids: [BidSchema],
    currentBid: { type: Number, default: 0 },
    winnerLabId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lab', default: null },
    settledAt: Date,
    status: { type: String, enum: ['active', 'sold', 'ended', 'removed'], default: 'active' },
}, { timestamps: true });

const MarketListing = mongoose.model('MarketListing', MarketListingSchema);
MarketListing.KINDS = KINDS;
module.exports = MarketListing;
