const mongoose = require('mongoose');

// A lab's request to fix its building or utilities (power, AC, water, ...).
// Lab equipment is not covered here: devices have their own service channel.
const CATEGORIES = ['electricity', 'ac', 'plumbing', 'building', 'furniture', 'internet', 'cleaning', 'other'];
const PRIORITIES = ['normal', 'urgent'];

const MaintenanceRequestSchema = new mongoose.Schema({
    requestNo: { type: Number, index: true },
    labId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lab', required: true, index: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    category: { type: String, enum: CATEGORIES, default: 'other' },
    priority: { type: String, enum: PRIORITIES, default: 'normal' },
    location: { type: String, trim: true, maxlength: 160, default: '' },
    description: { type: String, trim: true, maxlength: 4000, required: true },
    images: [{ type: String }],
    status: { type: String, enum: ['open', 'in_progress', 'done', 'cancelled'], default: 'open' },
    adminReply: { type: String, trim: true, maxlength: 4000, default: '' },
}, { timestamps: true });

const MaintenanceRequest = mongoose.model('MaintenanceRequest', MaintenanceRequestSchema);
MaintenanceRequest.CATEGORIES = CATEGORIES;
MaintenanceRequest.PRIORITIES = PRIORITIES;
module.exports = MaintenanceRequest;
