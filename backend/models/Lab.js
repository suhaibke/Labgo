const mongoose = require('mongoose');

const LabDocumentSchema = new mongoose.Schema({
    originalName: {
        type: String,
        required: true,
        trim: true,
    },
    url: {
        type: String,
        required: true,
    },
    storageKey: {
        type: String,
        required: true,
    },
    mimeType: {
        type: String,
        required: true,
    },
    size: {
        type: Number,
        min: 0,
    },
    uploadedAt: {
        type: Date,
        default: Date.now,
    },
}, { _id: true });

const LabDocumentsSchema = new mongoose.Schema({
    labCertificates: { type: [LabDocumentSchema], default: [] },
    labOpeningLetter: { type: [LabDocumentSchema], default: [] },
    labOpeningLicense: { type: [LabDocumentSchema], default: [] },
    practiceLicense: { type: [LabDocumentSchema], default: [] },
    ownerUnifiedCard: { type: [LabDocumentSchema], default: [] },
    ownerDepartmentOrRetirementId: { type: [LabDocumentSchema], default: [] },
}, { _id: false });

const LabSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
        trim: true,
    },

    email: {
        type: String,
        required: true,
        unique: true,
        trim: true,
        lowercase: true,
    },

    phone: {
        type: String,
        required: true,
        unique: true,
        trim: true,
    },

    address: {
        type: String,
        trim: true,
    },

    city: {
        type: String,
        required: true,
        trim: true,
    },

    zone: {
        type: String,
        trim: true,
    },

    country: {
        type: String,
        trim: true,
        default: 'Iraq',
    },

    website: {
        type: String,
        trim: true,
    },

    logo: {
        type: String,
        default: '',
    },

    // Wide banner image shown behind the logo on the lab's public profile
    coverImage: {
        type: String,
        default: '',
    },

    // Private registration documents. These are returned only from explicit
    // admin queries and are streamed through an authenticated endpoint.
    documents: {
        type: LabDocumentsSchema,
        default: () => ({}),
        select: false,
    },

    specialization: {
        type: [String],
        enum: ['Blood Tests', 'X-Ray', 'MRI', 'CT Scan', 'Ultrasound', 'Pathology', 'Microbiology', 'Biochemistry', 'Genetics', 'Allergy', 'Cardiology', 'Neurology', 'General'],
        default: ['Blood Tests'],
    },

    operatingHours: {
        monday: { open: String, close: String, closed: { type: Boolean, default: false } },
        tuesday: { open: String, close: String, closed: { type: Boolean, default: false } },
        wednesday: { open: String, close: String, closed: { type: Boolean, default: false } },
        thursday: { open: String, close: String, closed: { type: Boolean, default: false } },
        friday: { open: String, close: String, closed: { type: Boolean, default: false } },
        saturday: { open: String, close: String, closed: { type: Boolean, default: false } },
        sunday: { open: String, close: String, closed: { type: Boolean, default: false } },
    },

    tests: [{
        name: {
            type: String,
            required: true,
            trim: true,
        },
        nameAr: {
            type: String,
            trim: true,
            default: '',
        },
        code: {
            type: String,
            required: true,
            trim: true,
        },
        price: {
            type: Number,
            required: true,
            min: 0,
        },
        description: {
            type: String,
            trim: true,
        },
        instructions: {
            type: String,
            trim: true,
        },
        category: {
            type: String,
            enum: ['Blood Tests', 'X-Ray', 'MRI', 'CT Scan', 'Ultrasound', 'Pathology', 'Microbiology', 'Biochemistry', 'Genetics', 'Allergy', 'Cardiology', 'Neurology', 'General'],
            default: 'Blood Tests',
        },
        // Optional custom image shown in the patient app instead of the default test-tube icon.
        image: {
            type: String,
            trim: true,
            default: null,
        },
        // Result entry: unit and normal ranges used to flag values High/Low.
        // normalText is shown instead of min-max for text results (e.g. "Negative").
        unit: { type: String, trim: true, default: '' },
        normalText: { type: String, trim: true, default: '' },
        ranges: [{
            _id: false,
            gender: { type: String, enum: ['Both', 'Male', 'Female'], default: 'Both' },
            ageFrom: { type: Number, min: 0, default: 0 },
            ageTo: { type: Number, min: 0, default: 120 },
            ageUnit: { type: String, enum: ['Y', 'M', 'D'], default: 'Y' },
            min: { type: Number, default: null },
            max: { type: Number, default: null },
        }],
        // Links this test to an admin-managed quick Service, so the lab
        // shows up when a patient taps that service on the home page.
        serviceId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Service',
            default: null,
        },
    }],

    // Result report branding. The "Powered by LabGo" footer is shown unless
    // the platform admin turns it off (e.g. a paid plan). Labs cannot change it.
    reportBranding: {
        hidePlatformFooter: { type: Boolean, default: false },
        updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        updatedAt: Date,
    },

    // Staff roles: overrides of the built-in roles plus the lab's own roles.
    staffRoles: [{
        _id: false,
        key: { type: String, trim: true, required: true },
        name: { type: String, trim: true, default: '' },
        color: { type: String, trim: true, default: '' },
        permissions: [{ type: String, trim: true }],
    }],

    status: {
        type: String,
        enum: ['Active', 'Inactive', 'Pending', 'Suspended'],
        default: 'Active',
    },

    licenseNumber: {
        type: String,
        trim: true,
    },

    // People the lab is licensed under, printed in the report header in English
    // (e.g. Dr. Ahmed Hamdoon Ahmed · Bacteriologist).
    licenseHolders: [{
        _id: false,
        title: { type: String, trim: true, default: 'Dr.', maxlength: 20 },
        name: { type: String, trim: true, required: true, maxlength: 80 },
        specialty: { type: String, trim: true, default: '', maxlength: 60 },
    }],

    accreditation: {
        type: String,
        trim: true,
    },

    description: {
        type: String,
        trim: true,
    },

    totalPatientsServed: {
        type: Number,
        default: 0,
        min: 0,
    },

    totalTestsPerformed: {
        type: Number,
        default: 0,
        min: 0,
    },

    averageRating: {
        type: Number,
        default: 0,
        min: 0,
        max: 5,
    },

    totalReviews: {
        type: Number,
        default: 0,
        min: 0,
    },

    ownerId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },

    createdBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },

    lastUpdatedBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
    },

    patientTests: [{
        patientId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
            required: true,
        },
        testId: {
            type: mongoose.Schema.Types.ObjectId,
            required: true,
        },
        testName: {
            type: String,
            required: true,
        },
        requestDate: {
            type: Date,
            default: Date.now,
        },
        status: {
            type: String,
            enum: ['Pending', 'In Progress', 'Completed', 'Cancelled'],
            default: 'Pending',
        },
        resultDate: Date,
        urgency: {
            type: String,
            enum: ['Normal', 'Urgent', 'Emergency'],
            default: 'Normal',
        },
        price: Number,
        notes: String,
    }],

    isVerified: {
        type: Boolean,
        default: false,
    },

    isFeatured: {
        type: Boolean,
        default: false,
    },

    featuredAt: Date,

    verificationDate: Date,

    coordinates: {
        latitude: Number,
        longitude: Number,
    },

    paymentMethods: [{
        type: String,
        enum: ['Cash', 'Credit Card', 'Insurance', 'Online Payment'],
    }],

    insuranceProviders: [{
        type: String,
        trim: true,
    }],

    emergencyContact: {
        phone: String,
        email: String,
    },

    // ==================== COMMISSION & FINANCIAL ====================
    // Admin commission percentage (how much admin gets from every order)
    commissionRate: {
        type: Number,
        default: 0,
        min: 0,
        max: 100,
    },

    // ==================== OFFERS & DISCOUNTS ====================
    offers: [{
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
        label: {
            type: String,
            trim: true,
            default: '', // Short label shown on cards (e.g., "20% OFF", "SALE")
        },
        labelAr: {
            type: String,
            trim: true,
        },
        labelKu: {
            type: String,
            trim: true,
        },
        description: {
            type: String,
            trim: true,
        },
        descriptionAr: {
            type: String,
            trim: true,
        },
        descriptionKu: {
            type: String,
            trim: true,
        },
        discountType: {
            type: String,
            enum: ['percentage', 'fixed'],
            required: true,
            default: 'percentage',
        },
        discountValue: {
            type: Number,
            required: true,
            min: 0,
        },
        // Tests this offer applies to (if empty, applies to all tests)
        // Each test can have its own discount percentage/value
        applicableTests: [{
            testId: {
                type: mongoose.Schema.Types.ObjectId,
            },
            testCode: String,
            discountType: {
                type: String,
                enum: ['percentage', 'fixed'],
                default: 'percentage',
            },
            discountValue: {
                type: Number,
                default: 0,
                min: 0,
            },
        }],
        applyToAllTests: {
            type: Boolean,
            default: false,
        },
        minOrderAmount: {
            type: Number,
            default: 0,
        },
        maxDiscount: {
            type: Number,
            default: 0, // 0 means no limit
        },
        startDate: {
            type: Date,
            default: Date.now,
        },
        endDate: {
            type: Date,
        },
        isActive: {
            type: Boolean,
            default: true,
        },
        createdAt: {
            type: Date,
            default: Date.now,
        },
        // Admin starring - featured offers
        isStarred: {
            type: Boolean,
            default: false,
        },
        starredAt: {
            type: Date,
            default: null,
        },
        starredBy: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
            default: null,
        },
    }],

}, { timestamps: true });

// Add indexes for better performance
LabSchema.index({ name: 1 });
LabSchema.index({ email: 1 });
LabSchema.index({ phone: 1 });
LabSchema.index({ ownerId: 1 });
LabSchema.index({ status: 1 });
LabSchema.index({ 'patientTests.patientId': 1 });
LabSchema.index({ 'patientTests.requestDate': -1 });

const Lab = mongoose.model('Lab', LabSchema);
module.exports = Lab;
