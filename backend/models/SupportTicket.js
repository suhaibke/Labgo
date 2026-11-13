const mongoose = require('mongoose');

// A message from a lab to the LabGo team: a suggestion, a bug report or a problem.
const TYPES = ['suggestion', 'bug', 'problem', 'other'];

const SupportTicketSchema = new mongoose.Schema({
    ticketNo: { type: Number, index: true },
    labId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lab', required: true, index: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    type: { type: String, enum: TYPES, default: 'other' },
    subject: { type: String, trim: true, maxlength: 160, default: '' },
    message: { type: String, trim: true, maxlength: 4000, required: true },
    images: [{ type: String }],
    status: { type: String, enum: ['open', 'in_progress', 'closed'], default: 'open' },
    adminReply: { type: String, trim: true, maxlength: 4000, default: '' },
    adminSeenAt: { type: Date, default: null },
}, { timestamps: true });

const SupportTicket = mongoose.model('SupportTicket', SupportTicketSchema);
SupportTicket.TYPES = TYPES;
module.exports = SupportTicket;
