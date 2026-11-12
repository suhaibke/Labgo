const mongoose = require('mongoose');

const NurseApplicationSchema = new mongoose.Schema({
    // Applicant Information (User Reference)
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true,
    },

    // Personal Information (Pre-filled from User)
    personalInfo: {
        name: {
            type: String,
            required: true,
        },
        email: {
            type: String,
            required: false,
            default: null,
        },
        phone: {
            type: String,
            required: true,
        },
        dateOfBirth: {
            type: Date,
            required: true,
        },
        gender: {
            type: String,
            enum: ['male', 'female'],
            required: true,
        },
    },

    // National ID Card Images (البطاقة الموحدة)
    nationalCardImageFront: {
        type: String,
        required: true,
    },
    nationalCardImageBack: {
        type: String,
        required: true,
    },

    // Nursing Certificate Image
    certificateImage: {
        type: String,
        required: true,
    },

    // Home Location
    location: {
        city: {
            type: String,
            required: true,
        },
        zone: {
            type: String,
            required: true,
        },
        address: {
            type: String,
        },
        coordinates: {
            latitude: {
                type: Number,
            },
            longitude: {
                type: Number,
            },
        },
    },

    // Yes/No Questions
    questionnaire: {
        ownsCar: {
            type: Boolean,
            required: true,
        },
        isEmployed: {
            type: Boolean,
            required: true,
        },
    },

    // Application Status
    status: {
        type: String,
        enum: ['pending', 'under_review', 'approved', 'rejected', 'on_hold'],
        default: 'pending',
    },

    // Review Information (Admin)
    reviewDetails: {
        reviewedBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
        },
        reviewedAt: {
            type: Date,
        },
        notes: {
            type: String,
        },
        rejectionReason: {
            type: String,
        },
    },

    // Additional Information
    additionalInfo: {
        type: String,
        trim: true,
    },

    // Submission Timestamps
    submittedAt: {
        type: Date,
        default: Date.now,
    },

    // If approved, reference to the Nurse User account created
    nurseUserId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
    },
}, {
    timestamps: true,
});

// Indexes for better query performance
NurseApplicationSchema.index({ userId: 1 });
NurseApplicationSchema.index({ status: 1 });
NurseApplicationSchema.index({ submittedAt: -1 });
NurseApplicationSchema.index({ 'location.city': 1 });

// Static method to check if user has pending application
NurseApplicationSchema.statics.hasPendingApplication = function(userId) {
    return this.findOne({
        userId,
        status: { $in: ['pending', 'under_review', 'on_hold'] }
    });
};

// Static method to get application by user ID
NurseApplicationSchema.statics.getByUserId = function(userId) {
    return this.findOne({ userId }).sort({ submittedAt: -1 });
};

// Instance method to approve application
NurseApplicationSchema.methods.approve = function(adminId, nurseUserId, notes) {
    this.status = 'approved';
    this.reviewDetails = {
        reviewedBy: adminId,
        reviewedAt: new Date(),
        notes: notes,
    };
    this.nurseUserId = nurseUserId;
    return this.save();
};

// Instance method to reject application
NurseApplicationSchema.methods.reject = function(adminId, reason) {
    this.status = 'rejected';
    this.reviewDetails = {
        reviewedBy: adminId,
        reviewedAt: new Date(),
        rejectionReason: reason,
    };
    return this.save();
};

// Instance method to mark as under review
NurseApplicationSchema.methods.markAsUnderReview = function(adminId) {
    this.status = 'under_review';
    this.reviewDetails = {
        reviewedBy: adminId,
        reviewedAt: new Date(),
    };
    return this.save();
};

const NurseApplication = mongoose.model('NurseApplication', NurseApplicationSchema);

module.exports = NurseApplication;
