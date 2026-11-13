const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
    },

    email: {
        type: String,
        required: false,
        unique: true,
        // A `sparse` index only excludes documents where the field is
        // genuinely absent - a document with the field explicitly set to
        // null still counts as "having" it, so a `default: null` here
        // would make every patient who registers phone-only (no email)
        // collide on the same null value, and only the first one would
        // ever be able to save. Leaving no default keeps the field truly
        // unset when omitted, which is what sparse actually needs.
        sparse: true,
    },

    phone: {
        type: String,
        required: false,
        unique: true,
        sparse: true, // Same reasoning as email above - no default here.
    },

    city: {
        type: String,
        required: false, // Not required for existing users, but required in registration
        enum: ['بغداد', 'البصرة', 'نينوى', 'الأنبار', 'كركوك', 'صلاح الدين', 'ديالى', 'بابل', 'كربلاء', 'النجف', 'القادسية', 'المثنى', 'واسط', 'ذي قار', 'ميسان', 'أربيل', 'السليمانية', 'دهوك', null],
        default: null,
    },

    gender : {
        type: String,
        enum: ['male', 'female', null],
        required: false,
        default: null,
    },

    password: {
        type: String,
        required: true,
    },

    birthDate: {
        type: Date,
        required: false,
        default: null,
    },

    profilePicture: {
        type: String,
        default: null,
    },

    role: {
        type: String,
        enum: ['patient', 'nurse', 'lab', 'admin'],
        default: 'patient',
        required: true,
    },

    // ==================== FCM PUSH NOTIFICATION TOKENS ====================
    fcmTokens: [{
        token: { type: String, required: true },
        platform: { type: String, enum: ['ios', 'android'], required: true },
        createdAt: { type: Date, default: Date.now }
    }],

    // ==================== USER STATUS FIELDS ====================
    // User account status
    status: {
        type: String,
        enum: ['active', 'blocked', 'suspended'],
        default: 'active',
        required: true
    },

    // Block tracking fields
    blockedAt: {
        type: Date,
        default: null
    },

    blockedBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        default: null
    },

    blockReason: {
        type: String,
        default: null,
        trim: true,
        maxlength: 500
    },

    // ==================== NURSE FINANCIAL FIELDS ====================
    // Commission rate - percentage nurse owes admin from earnings
    nurseCommissionRate: {
        type: Number,
        default: 0,
        min: 0,
        max: 100,
    },
    // Balance accumulated by nurse from commissions (owes to admin)
    nurseBalance: {
        type: Number,
        default: 0,
        min: 0,
    },
    // Total lifetime earnings
    totalEarnings: {
        type: Number,
        default: 0,
        min: 0,
    },
    // Total amount paid to admin
    totalPaidToAdmin: {
        type: Number,
        default: 0,
        min: 0,
    },
    // Last balance settlement date
    lastSettlementDate: {
        type: Date,
        default: null,
    },

    // ==================== NURSE RATING FIELDS ====================
    // Average rating from patients (1-5)
    averageRating: {
        type: Number,
        default: 0,
        min: 0,
        max: 5,
    },
    // Total number of ratings received
    totalRatings: {
        type: Number,
        default: 0,
        min: 0,
    },

    // Nurse description (admin-editable, shown to patients)
    nurseDescription: {
        type: String,
        default: null,
        trim: true,
        maxlength: 500,
    },

    // OTP Verification Fields
    otpCode: {
        type: String,
        default: null,
    },

    otpExpiry: {
        type: Date,
        default: null,
    },

    otpMessageId: {
        type: String,
        default: null,
    },

    // Lab staff member (role 'lab', not the owner). Permissions come from
    // the role on the lab (Lab.staffRoles / built-in roles).
    labStaff: {
        labId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lab', default: null },
        roleKey: { type: String, trim: true, default: '' },
        active: { type: Boolean, default: true },
        addedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        addedAt: Date,
    },
    // Patient ID number shown to labs and on reports (e.g. 100245).
    // Given to every patient on first save; never changes.
    patientNo: {
        type: Number,
        unique: true,
        sparse: true,
    },
    // Account created by a lab for a walk-in patient (no password the patient knows).
    // Registering with the same phone through OTP claims it.
    labPlaceholder: {
        type: Boolean,
        default: false,
    },
    createdByLabId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Lab',
        default: null,
    },
    phoneVerified: {
        type: Boolean,
        default: false,
    },

    verificationAttempts: {
        type: Number,
        default: 0,
    },

    lastOtpSentAt: {
        type: Date,
        default: null,
    },

    // ==================== CART & ORDERING ====================

    // Shopping cart for tests (for patients)
    cart: {
        labId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Lab',
            default: null, // Cart is tied to a specific lab
        },
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
                type: Number,
                min: 0, // Original price before discount (optional)
            },
            // Set when this line item is part of a Package bundle - all
            // items sharing a packageId are added/removed together.
            packageId: {
                type: mongoose.Schema.Types.ObjectId,
                ref: 'Package',
                default: null,
            },
            addedAt: {
                type: Date,
                default: Date.now,
            },
        }],
        prescriptionImage: {
            type: String, // URL to temporary stored prescription image
            default: null,
        },
        totalPrice: {
            type: Number,
            default: 0,
            min: 0,
        },
        lastUpdated: {
            type: Date,
            default: Date.now,
        },
    },

    // Temporary storage for prescription image before order confirmation
    // Stores multiple uploaded images that expire after order is placed
    temporaryPrescriptions: [{
        imageUrl: {
            type: String,
            required: true,
        },
        uploadedAt: {
            type: Date,
            default: Date.now,
        },
        expiresAt: {
            type: Date,
            required: true,
        },
        used: {
            type: Boolean,
            default: false,
        },
        orderId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Order',
            default: null,
        },
    }],

    // Default location for home collection (saved by user)
    defaultLocation: {
        address: {
            type: String,
        },
        landmark: {
            type: String,
        },
        coordinates: {
            latitude: Number,
            longitude: Number,
        },
        buildingName: String,
        floorNumber: String,
        apartmentNumber: String,
        instructions: String,
    },

    // Favorite labs (patients) - list of Lab ids the user bookmarked
    favoriteLabs: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Lab',
    }],

    // Live GPS location (nurses only) - updated periodically while on an active order
    currentLocation: {
        latitude: {
            type: Number,
            min: -90,
            max: 90,
        },
        longitude: {
            type: Number,
            min: -180,
            max: 180,
        },
        updatedAt: Date,
    },

}, { timestamps: true });

// ==================== CART HELPER METHODS ====================

// Method to add test to cart
UserSchema.methods.addToCart = function(labId, test) {
    // If cart has items from a different lab, clear it first
    if (this.cart.labId && this.cart.labId.toString() !== labId.toString()) {
        this.cart.tests = [];
        this.cart.prescriptionImage = null;
    }

    this.cart.labId = labId;

    // Check if test already exists in cart
    const existingIndex = this.cart.tests.findIndex(
        t => t.testId.toString() === test._id.toString()
    );

    if (existingIndex === -1) {
        // Add new test to cart
        const cartItem = {
            testId: test._id,
            testName: test.nameAr || test.name,
            testCode: test.code,
            category: test.category || 'General',
            price: test.price,
            addedAt: new Date(),
        };
        
        // Add originalPrice if provided (when there's a discount)
        if (test.originalPrice && test.originalPrice !== test.price) {
            cartItem.originalPrice = test.originalPrice;
        }
        
        this.cart.tests.push(cartItem);
    }

    // Update total price
    this.calculateCartTotal();
    this.cart.lastUpdated = new Date();

    return this.save();
};

// Method to add a Package's tests to the cart as one unit - the package's
// combined price is distributed across the constituent tests proportionally
// to their own real prices, so calculateCartTotal (a plain sum) still adds
// up to exactly the package price with no other change needed.
UserSchema.methods.addPackageToCart = function(labId, pkg, tests) {
    if (this.cart.labId && this.cart.labId.toString() !== labId.toString()) {
        this.cart.tests = [];
        this.cart.prescriptionImage = null;
    }

    this.cart.labId = labId;

    // Drop any existing items from this same package first (re-adding replaces it).
    this.cart.tests = this.cart.tests.filter(
        t => !t.packageId || t.packageId.toString() !== pkg._id.toString()
    );

    const individualTotal = tests.reduce((sum, t) => sum + t.price, 0);
    let distributed = 0;

    tests.forEach((test, index) => {
        const isLast = index === tests.length - 1;
        const share = isLast
            ? pkg.price - distributed
            : Math.round((test.price / individualTotal) * pkg.price);
        distributed += share;

        this.cart.tests.push({
            testId: test._id,
            testName: test.nameAr || test.name,
            testCode: test.code,
            category: test.category || 'General',
            price: share,
            originalPrice: test.price !== share ? test.price : undefined,
            packageId: pkg._id,
            addedAt: new Date(),
        });
    });

    this.calculateCartTotal();
    this.cart.lastUpdated = new Date();

    return this.save();
};

// Method to remove test from cart
UserSchema.methods.removeFromCart = function(testId) {
    const target = this.cart.tests.find(t => t.testId.toString() === testId.toString());

    if (target && target.packageId) {
        // Packages are atomic in the cart - removing one item removes the whole bundle.
        this.cart.tests = this.cart.tests.filter(
            t => !t.packageId || t.packageId.toString() !== target.packageId.toString()
        );
    } else {
        this.cart.tests = this.cart.tests.filter(
            t => t.testId.toString() !== testId.toString()
        );
    }

    // If cart is empty, clear lab and prescription
    if (this.cart.tests.length === 0) {
        this.cart.labId = null;
        this.cart.prescriptionImage = null;
    }

    this.calculateCartTotal();
    this.cart.lastUpdated = new Date();

    return this.save();
};

// Method to calculate cart total
UserSchema.methods.calculateCartTotal = function() {
    this.cart.totalPrice = this.cart.tests.reduce((sum, test) => sum + test.price, 0);
    return this.cart.totalPrice;
};

// Method to clear cart
UserSchema.methods.clearCart = function() {
    this.cart = {
        labId: null,
        tests: [],
        prescriptionImage: null,
        totalPrice: 0,
        lastUpdated: new Date(),
    };
    return this.save();
};

// Method to set prescription image in cart
UserSchema.methods.setCartPrescription = function(imageUrl) {
    this.cart.prescriptionImage = imageUrl;
    this.cart.lastUpdated = new Date();
    return this.save();
};

// Method to remove prescription from cart
UserSchema.methods.removeCartPrescription = function() {
    this.cart.prescriptionImage = null;
    this.cart.lastUpdated = new Date();
    return this.save();
};

// Method to save temporary prescription image (before order confirmation)
UserSchema.methods.saveTemporaryPrescription = function(imageUrl, expiryHours = 24) {
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + expiryHours);

    this.temporaryPrescriptions.push({
        imageUrl,
        uploadedAt: new Date(),
        expiresAt,
        used: false,
    });

    return this.save();
};

// Method to mark temporary prescription as used
UserSchema.methods.markPrescriptionUsed = function(imageUrl, orderId) {
    const prescription = this.temporaryPrescriptions.find(
        p => p.imageUrl === imageUrl && !p.used
    );

    if (prescription) {
        prescription.used = true;
        prescription.orderId = orderId;
        return this.save();
    }

    return Promise.resolve(this);
};

// Method to get active (unused, non-expired) temporary prescriptions
UserSchema.methods.getActiveTemporaryPrescriptions = function() {
    const now = new Date();
    return this.temporaryPrescriptions.filter(
        p => !p.used && p.expiresAt > now
    );
};

// Method to clean up expired temporary prescriptions
UserSchema.methods.cleanupExpiredPrescriptions = function() {
    const now = new Date();
    this.temporaryPrescriptions = this.temporaryPrescriptions.filter(
        p => !p.used && p.expiresAt > now
    );
    return this.save();
};

// Method to set default location
UserSchema.methods.setDefaultLocation = function(locationData) {
    this.defaultLocation = {
        ...this.defaultLocation,
        ...locationData,
    };
    return this.save();
};

// Method to clear default location
UserSchema.methods.clearDefaultLocation = function() {
    this.defaultLocation = {
        address: null,
        landmark: null,
        coordinates: null,
        buildingName: null,
        floorNumber: null,
        apartmentNumber: null,
        instructions: null,
    };
    return this.save();
};

// Static method to clean up expired prescriptions for all users
UserSchema.statics.cleanupAllExpiredPrescriptions = function() {
    const now = new Date();
    return this.updateMany(
        {},
        {
            $pull: {
                temporaryPrescriptions: {
                    $or: [
                        { used: true },
                        { expiresAt: { $lt: now } }
                    ]
                }
            }
        }
    );
};

// Email is required for dashboard-login roles (admin/lab/nurse) but optional for patients,
// who register and log in with phone only.
UserSchema.pre('validate', function(next) {
    // Lab staff sign in with their phone, so email stays optional for them.
    const isLabStaff = this.role === 'lab' && this.labStaff && this.labStaff.labId;
    if (['admin', 'lab', 'nurse'].includes(this.role) && !this.email && !isLabStaff) {
        this.invalidate('email', 'Email is required for this account type');
    }
    next();
});

// Every patient gets a permanent ID number the first time they are saved.
UserSchema.pre('save', async function() {
    if (this.role === 'patient' && (this.patientNo === undefined || this.patientNo === null)) {
        const Counter = require('./Counter');
        this.patientNo = await Counter.next('patientNo', 100000);
    }
});

// Indexes for better query performance
UserSchema.index({ email: 1 });
UserSchema.index({ phone: 1 });
UserSchema.index({ role: 1 });
UserSchema.index({ city: 1 });
UserSchema.index({ 'cart.labId': 1 });
UserSchema.index({ 'temporaryPrescriptions.expiresAt': 1 });

module.exports = mongoose.model('User', UserSchema);