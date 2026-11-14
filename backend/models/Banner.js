const mongoose = require('mongoose');

// A single slide in the home page's promotional banner carousel.
const BannerSchema = new mongoose.Schema({
    imageUrl: {
        type: String,
        required: true,
    },
    // Where the slide shows: the patient app's home page or the labs' store.
    placement: {
        type: String,
        enum: ['home', 'lab_store'],
        default: 'home',
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

const model = mongoose.model('Banner', BannerSchema);
model.PLACEMENTS = ['home', 'lab_store'];
module.exports = model;
