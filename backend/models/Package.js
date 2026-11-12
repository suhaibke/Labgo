const mongoose = require('mongoose');

// A lab-managed bundle of that lab's own tests, sold together at one
// combined price the lab sets directly (unlike Lab.offers, which is a
// discount rule applied to existing test prices). Shown on the app's
// "الباقات" (Packages) browse screen across all labs.
const PackageSchema = new mongoose.Schema({
    labId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Lab',
        required: true,
        index: true,
    },
    name: {
        type: String,
        required: true,
        trim: true,
    },
    nameAr: {
        type: String,
        trim: true,
    },
    nameKu: {
        type: String,
        trim: true,
    },
    description: {
        type: String,
        trim: true,
        default: '',
    },
    descriptionAr: {
        type: String,
        trim: true,
        default: '',
    },
    descriptionKu: {
        type: String,
        trim: true,
        default: '',
    },
    category: {
        type: String,
        enum: ['General', 'Heart', 'Diabetes', 'Women'],
        default: 'General',
    },
    // References into this same lab's own Lab.tests[] subdocument _ids -
    // validated at write time (not a Mongoose ref, since tests are
    // embedded subdocuments rather than a top-level collection).
    testIds: [{
        type: mongoose.Schema.Types.ObjectId,
        required: true,
    }],
    // Combined price for the whole bundle, set directly by the lab -
    // independent of the sum of the individual tests' own prices.
    price: {
        type: Number,
        required: true,
        min: 0,
    },
    icon: {
        type: String,
        default: null,
    },
    isActive: {
        type: Boolean,
        default: true,
    },
    isMostRequested: {
        type: Boolean,
        default: false,
    },
}, { timestamps: true });

PackageSchema.index({ labId: 1, isActive: 1 });
PackageSchema.index({ name: 'text', nameAr: 'text' });

module.exports = mongoose.model('Package', PackageSchema);
