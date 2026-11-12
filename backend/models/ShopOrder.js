const mongoose = require('mongoose');
const crypto = require('crypto');

const ShopOrderSchema = new mongoose.Schema({
    // Unique order number for display (auto-generated in pre-save hook)
    orderNumber: {
        type: String,
        unique: true,
    },

    // Customer information (can be guest or logged-in user)
    customer: {
        // Linked user ID if logged in
        userId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
            default: null,
        },
        // Customer name
        name: {
            type: String,
            required: true,
            trim: true,
        },
        // Verified phone number
        phone: {
            type: String,
            required: true,
            trim: true,
        },
        // Phone verification status
        phoneVerified: {
            type: Boolean,
            default: false,
        },
        // OTP verification details
        verification: {
            messageId: String,
            verifiedAt: Date,
        },
    },

    // Delivery address
    deliveryAddress: {
        address: {
            type: String,
            required: true,
        },
        city: {
            type: String,
            default: '',
        },
        notes: {
            type: String,
            default: '',
        },
    },

    // Order items
    items: [{
        productId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Product',
            required: true,
        },
        // Snapshot of product details at time of order
        name: {
            en: String,
            ar: String,
            ku: String,
        },
        image: String,
        price: {
            type: Number,
            required: true,
        },
        quantity: {
            type: Number,
            required: true,
            min: 1,
        },
        subtotal: {
            type: Number,
            required: true,
        },
    }],

    // Pricing summary
    pricing: {
        subtotal: {
            type: Number,
            required: true,
        },
        deliveryFee: {
            type: Number,
            default: 0,
        },
        discount: {
            type: Number,
            default: 0,
        },
        total: {
            type: Number,
            required: true,
        },
        currency: {
            type: String,
            default: 'IQD',
        },
    },

    // Order status
    status: {
        type: String,
        enum: ['pending', 'processing', 'done', 'cancelled'],
        default: 'pending',
    },

    // Status history for tracking
    statusHistory: [{
        status: {
            type: String,
            enum: ['pending', 'processing', 'done', 'cancelled'],
        },
        changedAt: {
            type: Date,
            default: Date.now,
        },
        changedBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
        },
        notes: String,
    }],

    // Payment information
    payment: {
        method: {
            type: String,
            enum: ['cash_on_delivery', 'online'],
            default: 'cash_on_delivery',
        },
        status: {
            type: String,
            enum: ['pending', 'paid', 'failed', 'refunded'],
            default: 'pending',
        },
        paidAt: Date,
    },

    // Admin notes (internal) - array of note objects for history tracking
    adminNotes: {
        type: [{
            note: {
                type: String,
                required: true,
            },
            addedAt: {
                type: Date,
                default: Date.now,
            },
            addedBy: {
                type: mongoose.Schema.Types.ObjectId,
                ref: 'User',
            },
        }],
        default: [],
    },

    // Cancellation details
    cancellation: {
        cancelledAt: Date,
        cancelledBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
        },
        reason: String,
    },

}, {
    timestamps: true,
});

// Indexes for efficient queries
ShopOrderSchema.index({ status: 1, createdAt: -1 });
ShopOrderSchema.index({ 'customer.phone': 1 });
ShopOrderSchema.index({ 'customer.userId': 1 });
ShopOrderSchema.index({ orderNumber: 1 });

// Pre-save hook to convert old adminNotes string to array
ShopOrderSchema.pre('save', function(next) {
    // Convert old string format to array if needed
    if (typeof this.adminNotes === 'string') {
        this.adminNotes = this.adminNotes.trim()
            ? [{ note: this.adminNotes, addedAt: this.createdAt || new Date() }]
            : [];
    }
    next();
});

// Pre-save hook to generate order number
ShopOrderSchema.pre('save', async function(next) {
    if (this.isNew && !this.orderNumber) {
        // Generate unique order number: SHP-YYYYMMDD-XXXXX
        const date = new Date();
        const dateStr = date.toISOString().slice(0, 10).replace(/-/g, '');
        const random = crypto.randomBytes(3).toString('hex').toUpperCase();
        this.orderNumber = `SHP-${dateStr}-${random}`;
        
        // Add initial status to history
        this.statusHistory.push({
            status: 'pending',
            changedAt: new Date(),
            notes: 'Order placed',
        });
    }
    next();
});

// Method to update status
ShopOrderSchema.methods.updateStatus = async function(newStatus, userId, notes = '') {
    this.status = newStatus;
    this.statusHistory.push({
        status: newStatus,
        changedAt: new Date(),
        changedBy: userId,
        notes: notes,
    });
    
    if (newStatus === 'cancelled') {
        this.cancellation = {
            cancelledAt: new Date(),
            cancelledBy: userId,
            reason: notes,
        };
    }
    
    return this.save();
};

// Static method to get order statistics
ShopOrderSchema.statics.getStatistics = async function(startDate, endDate) {
    const match = {};
    if (startDate || endDate) {
        match.createdAt = {};
        if (startDate) match.createdAt.$gte = startDate;
        if (endDate) match.createdAt.$lte = endDate;
    }
    
    const stats = await this.aggregate([
        { $match: match },
        {
            $group: {
                _id: null,
                totalOrders: { $sum: 1 },
                totalRevenue: { $sum: '$pricing.total' },
                pendingCount: { 
                    $sum: { $cond: [{ $eq: ['$status', 'pending'] }, 1, 0] } 
                },
                processingCount: { 
                    $sum: { $cond: [{ $eq: ['$status', 'processing'] }, 1, 0] } 
                },
                doneCount: { 
                    $sum: { $cond: [{ $eq: ['$status', 'done'] }, 1, 0] } 
                },
                cancelledCount: { 
                    $sum: { $cond: [{ $eq: ['$status', 'cancelled'] }, 1, 0] } 
                },
            }
        }
    ]);
    
    return stats[0] || {
        totalOrders: 0,
        totalRevenue: 0,
        pendingCount: 0,
        processingCount: 0,
        doneCount: 0,
        cancelledCount: 0,
    };
};

// Virtual for item count
ShopOrderSchema.virtual('itemCount').get(function() {
    return this.items.reduce((total, item) => total + item.quantity, 0);
});

// Ensure virtuals are serialized
ShopOrderSchema.set('toJSON', { virtuals: true });
ShopOrderSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('ShopOrder', ShopOrderSchema);
