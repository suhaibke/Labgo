const mongoose = require('mongoose');

// A single slide in the home page's promotional banner carousel.
const BannerSchema = new mongoose.Schema({
    imageUrl: {
        type: String,
        required: true,
    },
    order: {
        type: Number,
        default: 0,
    },
    isActive: {
        type: Boolean,
        default: true,
    },
    createdBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
    },
}, { timestamps: true });

BannerSchema.index({ isActive: 1, order: 1 });

module.exports = mongoose.model('Banner', BannerSchema);
