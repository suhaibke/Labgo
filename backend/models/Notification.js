const mongoose = require('mongoose');

// A persisted copy of every push notification sent to a specific user
// (fcmService.sendToUser), so the in-app notifications list has real
// history instead of only whatever arrived while the device was reachable.
const NotificationSchema = new mongoose.Schema({
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true,
    },
    title: {
        type: String,
        required: true,
    },
    body: {
        type: String,
        required: true,
    },
    // Same free-form payload passed to FCM (type, orderId, ...) - the app
    // uses it to deep-link a tap straight to the relevant order.
    data: {
        type: mongoose.Schema.Types.Mixed,
        default: {},
    },
    isRead: {
        type: Boolean,
        default: false,
    },
}, { timestamps: true });

NotificationSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', NotificationSchema);
