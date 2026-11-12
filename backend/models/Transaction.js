const mongoose = require('mongoose');

/**
 * Transaction Model
 * Tracks all financial movements in the system:
 * - Patient pays nurse (order payment)
 * - Nurse pays lab (lab amount after commission deduction)
 * - Nurse pays admin (monthly balance settlement)
 * - Balance adjustments (admin corrections)
 */
const TransactionSchema = new mongoose.Schema({
    // Transaction type
    type: {
        type: String,
        enum: [
            'order_payment',      // Patient pays nurse for order
            'lab_settlement',     // Nurse pays lab their share
            'admin_settlement',   // Nurse pays admin from balance
            'balance_adjustment', // Admin adjusts nurse balance
            'commission_earned',  // Commission credited to nurse balance
        ],
        required: true,
    },

    // Amount in IQD
    amount: {
        type: Number,
        required: true,
        min: 0,
    },

    currency: {
        type: String,
        default: 'IQD',
    },

    // Related entities
    orderId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Order',
        default: null,
    },

    labId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Lab',
        default: null,
    },

    // For nurse transactions
    nurseId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        default: null,
    },

    // For patient payments
    patientId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        default: null,
    },

    // Admin who processed the transaction (for settlements/adjustments)
    processedBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        default: null,
    },

    // Description/notes
    description: {
        type: String,
        default: '',
    },

    // Reference number for tracking
    referenceNumber: {
        type: String,
        unique: true,
        required: true,
    },

    // Financial breakdown for order_payment type
    breakdown: {
        totalAmount: {
            type: Number,
            default: 0,
        },
        labAmount: {
            type: Number,
            default: 0,
        },
        adminCommission: {
            type: Number,
            default: 0,
        },
        commissionRate: {
            type: Number,
            default: 0,
        },
    },

    // Balance snapshot after transaction
    balanceAfter: {
        nurseBalance: {
            type: Number,
            default: null,
        },
    },

    // Status
    status: {
        type: String,
        enum: ['pending', 'completed', 'cancelled', 'reversed'],
        default: 'completed',
    },

    // Metadata
    metadata: {
        type: Map,
        of: mongoose.Schema.Types.Mixed,
        default: {},
    },

}, { timestamps: true });

// Indexes for efficient queries
TransactionSchema.index({ type: 1, createdAt: -1 });
TransactionSchema.index({ nurseId: 1, createdAt: -1 });
TransactionSchema.index({ labId: 1, createdAt: -1 });
TransactionSchema.index({ orderId: 1 });
TransactionSchema.index({ referenceNumber: 1 });
TransactionSchema.index({ processedBy: 1 });
TransactionSchema.index({ status: 1 });

// Static method to generate reference number
TransactionSchema.statics.generateReferenceNumber = function(type) {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substring(2, 6);
    const prefix = type.substring(0, 3).toUpperCase();
    return `TXN-${prefix}-${timestamp}-${random}`.toUpperCase();
};

// Static method to get nurse transaction summary
TransactionSchema.statics.getNurseTransactionSummary = async function(nurseId, startDate, endDate) {
    const query = { nurseId };
    if (startDate && endDate) {
        query.createdAt = { $gte: startDate, $lte: endDate };
    }

    const summary = await this.aggregate([
        { $match: query },
        {
            $group: {
                _id: '$type',
                totalAmount: { $sum: '$amount' },
                count: { $sum: 1 },
            }
        }
    ]);

    return summary;
};

// Static method to get lab transaction summary
TransactionSchema.statics.getLabTransactionSummary = async function(labId, startDate, endDate) {
    const query = { labId };
    if (startDate && endDate) {
        query.createdAt = { $gte: startDate, $lte: endDate };
    }

    const summary = await this.aggregate([
        { $match: query },
        {
            $group: {
                _id: '$type',
                totalAmount: { $sum: '$amount' },
                count: { $sum: 1 },
            }
        }
    ]);

    return summary;
};

// Static method to get admin revenue summary
TransactionSchema.statics.getAdminRevenueSummary = async function(startDate, endDate) {
    const query = {
        type: { $in: ['commission_earned', 'admin_settlement'] },
        status: 'completed',
    };
    if (startDate && endDate) {
        query.createdAt = { $gte: startDate, $lte: endDate };
    }

    const summary = await this.aggregate([
        { $match: query },
        {
            $group: {
                _id: '$type',
                totalAmount: { $sum: '$amount' },
                count: { $sum: 1 },
            }
        }
    ]);

    return summary;
};

const Transaction = mongoose.model('Transaction', TransactionSchema);
module.exports = Transaction;
