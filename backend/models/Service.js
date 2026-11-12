const mongoose = require('mongoose');

// A canonical, admin-managed "quick service" (e.g. "فيتامين D") shown as a
// scrollable shortcut row on the app's home page. Labs link their own tests
// to a Service (via Lab.tests[].serviceId) to indicate they offer it.
const ServiceSchema = new mongoose.Schema({
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
    subtitle: {
        // Short secondary line shown under the name, e.g. "CBC"
        type: String,
        trim: true,
    },
    icon: {
        // R2 URL of the admin-uploaded icon image (capped at 200KB)
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
}, { timestamps: true });

ServiceSchema.index({ order: 1 });

module.exports = mongoose.model('Service', ServiceSchema);
