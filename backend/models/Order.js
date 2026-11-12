const mongoose = require('mongoose');

const OrderSchema = new mongoose.Schema({
    // Patient who placed the order
    patientId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true,
    },

    // Beneficiary information (if order is for another person)
    beneficiary: {
        isForOtherPerson: {
            type: Boolean,
            default: false,
        },
        name: {
            type: String,
        },
        phone: {
            type: String,
        },
        gender: {
            type: String,
            enum: ['male', 'female'],
        },
        birthDate: {
            type: Date,
        },
        relationship: {
            type: String, // e.g., 'spouse', 'child', 'parent', 'sibling', 'other'
        },
    },

    // Lab where tests will be conducted (optional for nurse requests - admin assigns later)
    labId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Lab',
        required: false,  // Made optional for nurse requests
        index: true,
        default: null,
    },

    // Flag to indicate this is a nurse request without pre-selected lab
    isNurseRequest: {
        type: Boolean,
        default: false,
    },

    // Nurse assigned for home sample collection (optional)
    nurseId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        index: true,
        default: null,
    },

    // Tests ordered
    tests: [{
        testId: {
            type: mongoose.Schema.Types.ObjectId,
            required: true,
        },
        testName: {
            type: String,
            required: true,
        },
        testCode: {
            type: String,
            required: true,
        },
        category: {
            type: String,
        },
        price: {
            type: Number,
            required: true,
            min: 0,
        },
        originalPrice: {
            type: Number, // Original price before discount (if discounted)
            min: 0,
        },
    }],

    // Prescription image (uploaded by patient)
    prescriptionImage: {
        type: String, // URL to stored image
        default: null,
    },

    // QR Code for nurse to scan at patient location
    qrCode: {
        type: String,
        required: true,
        unique: true,
        index: true,
    },

    // QR Code scan status
    qrScanned: {
        scanned: {
            type: Boolean,
            default: false,
        },
        scannedAt: {
            type: Date,
        },
        scannedBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
        },
    },

    // Scheduled/appointment time (optional for home collection)
    scheduledDate: {
        type: Date,
        required: false,
    },

    // Time slot for appointment (optional)
    timeSlot: {
        start: {
            type: String, // Format: "09:00"
        },
        end: {
            type: String, // Format: "10:00"
        },
    },

    // Sample collection location (for home visits) - REQUIRED
    location: {
        address: {
            type: String,
            required: true,
        },
        landmark: {
            type: String,
        },
        coordinates: {
            latitude: {
                type: Number,
                required: true,
                min: -90,
                max: 90,
            },
            longitude: {
                type: Number,
                required: true,
                min: -180,
                max: 180,
            },
        },
        // Additional location details
        buildingName: String,
        floorNumber: String,
        apartmentNumber: String,
        instructions: String, // e.g., "Ring the bell twice", "Call upon arrival"
        phone: String,
    },

    // Order type - always home collection for this workflow
    orderType: {
        type: String,
        enum: ['home_collection'],
        default: 'home_collection',
    },

    // Urgency level
    urgency: {
        type: String,
        enum: ['routine', 'urgent', 'emergency'],
        default: 'routine',
    },

    // Order status tracking
    status: {
        type: String,
        enum: [
            'pending',           // Order placed, awaiting admin confirmation
            'quoted',            // Prescription orders only: admin set a price, awaiting patient approval
            'confirmed',         // Admin confirmed the order (waiting for nurse)
            'nurse_assigned',    // Nurse accepted the order (nurse on the way)
            'sample_collected',  // Nurse scanned patient QR - blood sample collected
            'at_lab',            // Lab scanned QR - sample received at lab
            'completed',         // Tests completed, results ready
            'cancelled',         // Order cancelled
        ],
        default: 'pending',
    },

    // Which of the two order types this is. Test orders are priced by the
    // lab's own test catalog; prescription orders are priced manually by
    // the admin and require the patient's approval before proceeding.
    orderCategory: {
        type: String,
        enum: ['test', 'prescription'],
        default: 'test',
    },

    // For prescription orders: distinguishes a lab-test prescription (normal
    // home-collection lifecycle) from a medicine prescription (delivery only:
    // admin prices it, patient approves, order is confirmed for delivery).
    prescriptionType: {
        type: String,
        enum: ['lab_test', 'medicine'],
        default: 'lab_test',
    },

    // Prescription orders only: the admin's price quote and the patient's response to it
    prescriptionQuote: {
        // Lab-test prescriptions: the tests the admin read off the
        // prescription, each with its own price. `price` holds the total.
        tests: [{
            name: { type: String, trim: true },
            price: { type: Number, min: 0 },
        }],
        medicineName: { type: String, trim: true },
        medicineType: { type: String, trim: true },
        price: { type: Number, min: 0 },
        imageUrl: { type: String, trim: true },
        notes: { type: String, trim: true, maxlength: 1000 },
        quotedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        quotedAt: Date,
        approved: { type: Boolean, default: null },
        respondedAt: Date,
    },

    // Admin confirmation section
    adminConfirmation: {
        confirmed: {
            type: Boolean,
            default: false,
        },
        confirmedBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
        },
        confirmedAt: {
            type: Date,
        },
        rejectionReason: {
            type: String,
        },
        notes: String,
    },

    // Nurse assignment details
    nurseAssignment: {
        assignedAt: {
            type: Date,
        },
        acceptedAt: {
            type: Date,
        },
        estimatedArrival: {
            type: Date,
        },
        notes: String,
    },

    // Snapshot of the technician's map coordinates (live GPS or default
    // base location). Stored on the order so the patient tracking map can
    // show the nurse even before a live ping arrives.
    nurseMapLocation: {
        latitude: Number,
        longitude: Number,
        updatedAt: Date,
    },

    // Payment information (Cash only)
    payment: {
        status: {
            type: String,
            enum: ['pending', 'paid', 'refunded'],
            default: 'pending',
        },
        method: {
            type: String,
            enum: ['cash'],
            default: 'cash',
        },
        amount: {
            type: Number,
            required: true,
            min: 0,
        },
        currency: {
            type: String,
            default: 'IQD',
        },
        paidAt: {
            type: Date,
        },
        collectedBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
        },
    },

    // Pricing breakdown
    // Set when a coupon discount was applied at checkout (see pricing.discount for the amount).
    couponCode: {
        type: String,
        default: null,
    },
    pricing: {
        subtotal: {
            type: Number,
            required: true,
            min: 0,
        },
        urgencyFee: {
            type: Number,
            default: 0,
            min: 0,
        },
        discount: {
            type: Number,
            default: 0,
            min: 0,
        },
        total: {
            type: Number,
            required: true,
            min: 0,
        },
    },

    // Track if payment collected
    paymentCollected: {
        collected: {
            type: Boolean,
            default: false,
        },
        collectedAt: {
            type: Date,
        },
        collectedBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
        },
    },

    // Status tracking timeline
    statusHistory: [{
        status: {
            type: String,
            required: true,
        },
        timestamp: {
            type: Date,
            default: Date.now,
        },
        updatedBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
        },
        notes: String,
    }],

    // Results information
    results: {
        reportUrl: {
            type: String,
        },
        completedAt: {
            type: Date,
        },
        notified: {
            type: Boolean,
            default: false,
        },
        // Values entered by the lab, one per ordered test. The reference range
        // is copied at entry time so later catalogue edits don't change old reports.
        values: [{
            _id: false,
            testId: { type: mongoose.Schema.Types.ObjectId },
            testName: { type: String, trim: true },
            value: { type: String, trim: true, default: '' },
            unit: { type: String, trim: true, default: '' },
            min: { type: Number, default: null },
            max: { type: Number, default: null },
            normalText: { type: String, trim: true, default: '' },
            flag: { type: String, enum: ['', 'normal', 'low', 'high'], default: '' },
        }],
        comment: { type: String, trim: true, default: '' },
        entryStatus: { type: String, enum: ['none', 'draft', 'approved'], default: 'none' },
        enteredAt: Date,
        enteredBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        approvedAt: Date,
        approvedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    },

    // Cancellation details
    cancellation: {
        reason: {
            type: String,
        },
        cancelledBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
        },
        cancelledAt: {
            type: Date,
        },
        refundAmount: {
            type: Number,
        },
    },

    // Nurse cancellation history (when nurses release orders back to available)
    nurseCancellations: [{
        nurseId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
        },
        reason: {
            type: String,
        },
        cancelledAt: {
            type: Date,
            default: Date.now,
        },
    }],

    // Notes and additional information
    notes: {
        patientNotes: String,      // Notes from patient
        labNotes: String,          // Notes from lab
        nurseNotes: String,        // Notes from nurse
    },

    // Notifications tracking
    notifications: {
        smsSent: {
            type: Boolean,
            default: false,
        },
        emailSent: {
            type: Boolean,
            default: false,
        },
        pushSent: {
            type: Boolean,
            default: false,
        },
    },

    // Rating and feedback (after completion)
    rating: {
        labRating: {
            type: Number,
            min: 1,
            max: 5,
        },
        labRatingReason: {
            type: String,
            trim: true,
        },
        nurseRating: {
            type: Number,
            min: 1,
            max: 5,
        },
        nurseRatingReason: {
            type: String,
            trim: true,
        },
        serviceRating: {
            type: Number,
            min: 1,
            max: 5,
        },
        feedback: String,
        ratedAt: {
            type: Date,
        },
    },

    // ==================== FINANCIAL BREAKDOWN ====================
    // Commission and payment distribution for business model
    // Flow: Patient pays total → Nurse pays lab (total - labCommission%) → Admin takes nurse's %
    financials: {
        // Lab's commission rate at the time of order (snapshot)
        labCommissionRate: {
            type: Number,
            default: 0,
            min: 0,
            max: 100,
        },
        // Nurse's commission rate at the time of order (what nurse owes admin)
        nurseCommissionRate: {
            type: Number,
            default: 0,
            min: 0,
            max: 100,
        },
        // Amount nurse pays to lab (total - lab's commission)
        labAmount: {
            type: Number,
            default: 0,
            min: 0,
        },
        // Amount nurse keeps after paying lab (lab's commission = nurse's earning before admin cut)
        nurseEarningBeforeAdmin: {
            type: Number,
            default: 0,
            min: 0,
        },
        // Amount that goes to admin (nurse's % of nurseEarningBeforeAdmin)
        adminAmount: {
            type: Number,
            default: 0,
            min: 0,
        },
        // Final amount nurse keeps after paying admin
        nurseNetEarning: {
            type: Number,
            default: 0,
            min: 0,
        },
        // Whether nurse has settled with the lab
        labSettled: {
            type: Boolean,
            default: false,
        },
        labSettledAt: {
            type: Date,
        },
        labSettledBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
        },
        // Whether nurse has settled with admin
        adminSettled: {
            type: Boolean,
            default: false,
        },
        adminSettledAt: {
            type: Date,
        },
        adminSettledBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
        },
    },

}, {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true }
});

// Indexes for better query performance
OrderSchema.index({ patientId: 1, createdAt: -1 });
OrderSchema.index({ labId: 1, status: 1 });
OrderSchema.index({ nurseId: 1, status: 1 });
OrderSchema.index({ status: 1 });
OrderSchema.index({ scheduledDate: 1 });
OrderSchema.index({ 'payment.status': 1 });
OrderSchema.index({ createdAt: -1 });
OrderSchema.index({ qrCode: 1 });
OrderSchema.index({ 'adminConfirmation.confirmed': 1 });
OrderSchema.index({ 'qrScanned.scanned': 1 });

// Static method to generate unique QR code
OrderSchema.statics.generateQRCode = function () {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substring(2, 8);
    return `LG-${timestamp}-${random}`.toUpperCase();
};

// Virtual for order age
OrderSchema.virtual('orderAge').get(function () {
    return Date.now() - this.createdAt;
});

// Virtual for order completion time
OrderSchema.virtual('completionTime').get(function () {
    if (this.results?.completedAt) {
        return this.results.completedAt - this.createdAt;
    }
    return null;
});

// Pre-save middleware to update status history
OrderSchema.pre('save', function (next) {
    if (this.isModified('status')) {
        this.statusHistory.push({
            status: this.status,
            timestamp: new Date(),
        });
    }
    next();
});

// Static method to get orders by status
OrderSchema.statics.getByStatus = function (status) {
    return this.find({ status }).populate('patientId labId nurseId');
};

// Static method to get patient orders
OrderSchema.statics.getPatientOrders = function (patientId) {
    return this.find({ patientId })
        .populate('labId nurseId')
        .sort({ createdAt: -1 });
};

// Static method to get lab orders
OrderSchema.statics.getLabOrders = function (labId, status) {
    const query = { labId };
    if (status) query.status = status;
    return this.find(query)
        .populate('patientId nurseId')
        .sort({ createdAt: -1 });
};

// Instance method to calculate total pricing
OrderSchema.methods.calculateTotal = function () {
    const subtotal = this.tests.reduce((sum, test) => sum + test.price, 0);
    this.pricing.subtotal = subtotal;
    this.pricing.total = subtotal + this.pricing.urgencyFee - this.pricing.discount;
    this.payment.amount = this.pricing.total;
    return this.pricing.total;
};

// Instance method to calculate financial breakdown based on lab and nurse commission rates
// Flow: Patient pays total → Nurse pays lab (total - labCommission%) → Admin takes nurse's %
OrderSchema.methods.calculateFinancials = async function () {
    const Lab = require('./Lab');
    const User = require('./User');

    const lab = await Lab.findById(this.labId);
    if (!lab) {
        throw new Error('Lab not found for financial calculation');
    }

    // Get nurse commission rate if nurse is assigned
    let nurseCommissionRate = 0;
    if (this.nurseId) {
        const nurse = await User.findById(this.nurseId);
        if (nurse) {
            nurseCommissionRate = nurse.nurseCommissionRate || 0;
        }
    }

    const total = this.pricing.total;
    const labCommissionRate = lab.commissionRate || 0;

    // Lab gets (100 - labCommissionRate)% of total
    // Nurse keeps labCommissionRate% as their earning (before admin cut)
    const nurseEarningBeforeAdmin = Math.round((total * labCommissionRate) / 100);
    const labAmount = total - nurseEarningBeforeAdmin;

    // Admin gets nurseCommissionRate% of nurse's earning
    const adminAmount = Math.round((nurseEarningBeforeAdmin * nurseCommissionRate) / 100);
    const nurseNetEarning = nurseEarningBeforeAdmin - adminAmount;

    this.financials = {
        labCommissionRate: labCommissionRate,
        nurseCommissionRate: nurseCommissionRate,
        labAmount: labAmount,
        nurseEarningBeforeAdmin: nurseEarningBeforeAdmin,
        adminAmount: adminAmount,
        nurseNetEarning: nurseNetEarning,
        labSettled: false,
        adminSettled: false,
    };

    return this.financials;
};

// Instance method to update status with history
OrderSchema.methods.updateStatus = function (newStatus, updatedBy, notes) {
    this.status = newStatus;
    this.statusHistory.push({
        status: newStatus,
        timestamp: new Date(),
        updatedBy,
        notes,
    });
    return this.save();
};

// Instance method for admin to confirm order
// Instance method for admin to set a price quote on a prescription order
OrderSchema.methods.quotePrescription = function (adminId, quote) {
    this.prescriptionQuote = {
        tests: quote.tests || [],
        medicineName: quote.medicineName,
        medicineType: quote.medicineType,
        price: quote.price,
        imageUrl: quote.imageUrl,
        notes: quote.notes,
        quotedBy: adminId,
        quotedAt: new Date(),
        approved: null,
        respondedAt: null,
    };
    this.status = 'quoted';
    this.statusHistory.push({
        status: 'quoted',
        timestamp: new Date(),
        updatedBy: adminId,
        notes: 'Admin set a price quote for the prescription',
    });
    return this.save();
};

// Instance method for the patient to approve or reject a prescription price quote
OrderSchema.methods.respondToPrescriptionQuote = function (patientId, approved) {
    this.prescriptionQuote.approved = approved;
    this.prescriptionQuote.respondedAt = new Date();

    if (approved) {
        this.pricing.subtotal = this.prescriptionQuote.price || 0;
        this.pricing.total = this.prescriptionQuote.price || 0;
        this.payment.amount = this.prescriptionQuote.price || 0;

        if (this.prescriptionType === 'medicine') {
            // Medicine delivery: patient approval is the confirmation —
            // no lab/nurse round-trip needed before proceeding.
            this.status = 'confirmed';
            this.adminConfirmation.confirmed = true;
            this.adminConfirmation.confirmedAt = new Date();
            this.statusHistory.push({
                status: 'confirmed',
                timestamp: new Date(),
                updatedBy: patientId,
                notes: 'Patient approved the medicine price quote - order confirmed for delivery',
            });
            return this.save();
        }

        // Lab-test prescription: materialize the quoted tests onto the order
        // itself so the rest of the lifecycle (nurse, lab, patient views)
        // sees them like a normal test order.
        const quotedTests = this.prescriptionQuote.tests || [];
        if (quotedTests.length > 0 && this.tests.length === 0) {
            this.tests = quotedTests.map(t => ({
                testId: new mongoose.Types.ObjectId(),
                testName: t.name,
                testCode: 'RX',
                category: 'Prescription',
                price: t.price || 0,
            }));
        }
        this.status = 'pending';
        this.statusHistory.push({
            status: 'pending',
            timestamp: new Date(),
            updatedBy: patientId,
            notes: 'Patient approved the prescription price quote',
        });
    } else {
        this.status = 'cancelled';
        this.cancellation = {
            cancelledBy: patientId,
            cancelledAt: new Date(),
            reason: 'Patient rejected the prescription price quote',
        };
        this.statusHistory.push({
            status: 'cancelled',
            timestamp: new Date(),
            updatedBy: patientId,
            notes: 'Patient rejected the prescription price quote',
        });
    }

    return this.save();
};

OrderSchema.methods.confirmOrder = function (adminId, notes) {
    this.adminConfirmation.confirmed = true;
    this.adminConfirmation.confirmedBy = adminId;
    this.adminConfirmation.confirmedAt = new Date();
    this.adminConfirmation.notes = notes;
    this.status = 'confirmed';
    this.statusHistory.push({
        status: 'confirmed',
        timestamp: new Date(),
        updatedBy: adminId,
        notes: notes || 'Order confirmed by admin',
    });
    return this.save();
};

// Instance method for admin to reject order
OrderSchema.methods.rejectOrder = function (adminId, reason) {
    this.adminConfirmation.confirmed = false;
    this.adminConfirmation.confirmedBy = adminId;
    this.adminConfirmation.confirmedAt = new Date();
    this.adminConfirmation.rejectionReason = reason;
    this.status = 'cancelled';
    this.statusHistory.push({
        status: 'cancelled',
        timestamp: new Date(),
        updatedBy: adminId,
        notes: `Order rejected: ${reason}`,
    });
    return this.save();
};

// Instance method for nurse to accept order
// Instance method for admin to manually assign a nurse to a confirmed order
OrderSchema.methods.adminAssignNurse = function (nurseId, adminId) {
    this.nurseId = nurseId;
    this.nurseAssignment.assignedAt = new Date();
    this.nurseAssignment.acceptedAt = new Date();
    this.status = 'nurse_assigned';
    this.statusHistory.push({
        status: 'nurse_assigned',
        timestamp: new Date(),
        updatedBy: adminId,
        notes: 'Nurse assigned by admin',
    });
    return this.save();
};

OrderSchema.methods.nurseAcceptOrder = function (nurseId, estimatedArrival) {
    this.nurseId = nurseId;
    this.nurseAssignment.assignedAt = new Date();
    this.nurseAssignment.acceptedAt = new Date();
    this.nurseAssignment.estimatedArrival = estimatedArrival;
    this.status = 'nurse_assigned';
    this.statusHistory.push({
        status: 'nurse_assigned',
        timestamp: new Date(),
        updatedBy: nurseId,
        notes: 'Order accepted by nurse',
    });
    return this.save();
};

// Instance method for nurse to scan QR at patient location (sample collected)
OrderSchema.methods.scanQRCode = function (nurseId) {
    this.qrScanned.scanned = true;
    this.qrScanned.scannedAt = new Date();
    this.qrScanned.scannedBy = nurseId;
    this.status = 'sample_collected';
    this.statusHistory.push({
        status: 'sample_collected',
        timestamp: new Date(),
        updatedBy: nurseId,
        notes: 'Blood sample collected from patient',
    });
    return this.save();
};

// Instance method for lab to scan QR and receive sample
OrderSchema.methods.labReceiveSample = function (labUserId) {
    this.status = 'at_lab';
    this.statusHistory.push({
        status: 'at_lab',
        timestamp: new Date(),
        updatedBy: labUserId,
        notes: 'Sample received at lab',
    });
    return this.save();
};

// Medicine-delivery orders: admin marks the order delivered after the
// patient approved the quote (status is already `confirmed`).
OrderSchema.methods.markDelivered = function (adminId) {
    this.status = 'completed';
    this.statusHistory.push({
        status: 'completed',
        timestamp: new Date(),
        updatedBy: adminId,
        notes: 'Medicine delivered',
    });
    return this.save();
};

// Instance method to mark order as completed
OrderSchema.methods.markCompleted = function (labUserId, reportUrl) {
    const completedAt = new Date();
    this.status = 'completed';
    // Keep any entered result values; only set the report and completion fields.
    if (!this.results) this.results = {};
    this.results.reportUrl = reportUrl || null;
    this.results.completedAt = completedAt;
    this.results.notified = false;
    this.statusHistory.push({
        status: 'completed',
        timestamp: completedAt,
        updatedBy: labUserId,
        notes: 'Tests completed',
    });
    return this.save();
};

// Instance method to mark payment as collected
OrderSchema.methods.markPaymentCollected = function (collectedBy) {
    this.paymentCollected.collected = true;
    this.paymentCollected.collectedAt = new Date();
    this.paymentCollected.collectedBy = collectedBy;
    this.payment.status = 'paid';
    this.payment.paidAt = new Date();
    this.payment.collectedBy = collectedBy;
    return this.save();
};

const Order = mongoose.model('Order', OrderSchema);
module.exports = Order;
