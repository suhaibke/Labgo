const mongoose = require('mongoose');

const ProductSchema = new mongoose.Schema({
    // Product name (multilingual)
    name: {
        en: {
            type: String,
            required: true,
            trim: true,
        },
        ar: {
            type: String,
            required: true,
            trim: true,
        },
        ku: {
            type: String,
            required: true,
            trim: true,
        },
    },

    // Product description (multilingual)
    description: {
        en: {
            type: String,
            trim: true,
            default: '',
        },
        ar: {
            type: String,
            trim: true,
            default: '',
        },
        ku: {
            type: String,
            trim: true,
            default: '',
        },
    },

    // Short description for listings (multilingual)
    shortDescription: {
        en: {
            type: String,
            trim: true,
            maxlength: 200,
            default: '',
        },
        ar: {
            type: String,
            trim: true,
            maxlength: 200,
            default: '',
        },
        ku: {
            type: String,
            trim: true,
            maxlength: 200,
            default: '',
        },
    },

    // Category reference
    category: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Category',
        required: true,
        index: true,
    },

    // Product images (array for multiple images)
    images: [{
        url: {
            type: String,
            required: true,
        },
        alt: {
            type: String,
            default: '',
        },
        isPrimary: {
            type: Boolean,
            default: false,
        },
    }],

    // Pricing
    price: {
        type: Number,
        required: true,
        min: 0,
    },

    // Compare at price (for showing discounts)
    compareAtPrice: {
        type: Number,
        min: 0,
        default: null,
    },

    // Currency (default IQD for Iraq)
    currency: {
        type: String,
        default: 'IQD',
    },

    // Inventory management
    inventory: {
        // Whether to track inventory
        trackInventory: {
            type: Boolean,
            default: false,
        },
        // Current stock quantity
        quantity: {
            type: Number,
            default: 0,
            min: 0,
        },
        // Allow ordering when out of stock
        allowBackorder: {
            type: Boolean,
            default: false,
        },
        // Low stock threshold for alerts
        lowStockThreshold: {
            type: Number,
            default: 5,
        },
    },

    // Product status
    status: {
        type: String,
        enum: ['active', 'inactive', 'draft'],
        default: 'draft',
    },

    // Featured product flag
    isFeatured: {
        type: Boolean,
        default: false,
    },

    // Product tags for search/filtering
    tags: [{
        type: String,
        trim: true,
    }],

    // SEO slug
    slug: {
        type: String,
        unique: true,
        lowercase: true,
        trim: true,
    },

    // Product specifications/attributes
    specifications: [{
        key: {
            en: String,
            ar: String,
            ku: String,
        },
        value: {
            en: String,
            ar: String,
            ku: String,
        },
    }],

    // Sales statistics (cached)
    stats: {
        totalSold: {
            type: Number,
            default: 0,
        },
        totalRevenue: {
            type: Number,
            default: 0,
        },
        viewCount: {
            type: Number,
            default: 0,
        },
    },

    // Created by admin
    createdBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
    },

}, {
    timestamps: true,
});

// Indexes for efficient queries
ProductSchema.index({ status: 1, isFeatured: -1, createdAt: -1 });
ProductSchema.index({ category: 1, status: 1 });
ProductSchema.index({ slug: 1 });
ProductSchema.index({ tags: 1 });
ProductSchema.index({ 'name.en': 'text', 'name.ar': 'text', 'name.ku': 'text', 'description.en': 'text' });

// Pre-save hook to generate slug
ProductSchema.pre('save', function(next) {
    if (this.isModified('name.en') || !this.slug) {
        const timestamp = Date.now().toString(36);
        this.slug = this.name.en
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/(^-|-$)/g, '') + '-' + timestamp;
    }
    next();
});

// Virtual for primary image
ProductSchema.virtual('primaryImage').get(function() {
    const primary = this.images.find(img => img.isPrimary);
    return primary ? primary.url : (this.images[0]?.url || null);
});

// Virtual for discount percentage
ProductSchema.virtual('discountPercentage').get(function() {
    if (this.compareAtPrice && this.compareAtPrice > this.price) {
        return Math.round(((this.compareAtPrice - this.price) / this.compareAtPrice) * 100);
    }
    return 0;
});

// Virtual for in-stock status
ProductSchema.virtual('inStock').get(function() {
    if (!this.inventory.trackInventory) return true;
    return this.inventory.quantity > 0 || this.inventory.allowBackorder;
});

// Methods for localization
ProductSchema.methods.getLocalizedName = function(lang = 'en') {
    return this.name[lang] || this.name.en;
};

ProductSchema.methods.getLocalizedDescription = function(lang = 'en') {
    return this.description[lang] || this.description.en;
};

ProductSchema.methods.getLocalizedShortDescription = function(lang = 'en') {
    return this.shortDescription[lang] || this.shortDescription.en;
};

// Static method to update category product count
ProductSchema.statics.updateCategoryProductCount = async function(categoryId) {
    const Category = mongoose.model('Category');
    const count = await this.countDocuments({ 
        category: categoryId, 
        status: 'active' 
    });
    await Category.findByIdAndUpdate(categoryId, { productCount: count });
};

// Post-save hook to update category product count
ProductSchema.post('save', async function() {
    await this.constructor.updateCategoryProductCount(this.category);
});

// Post-remove hook to update category product count
ProductSchema.post('remove', async function() {
    await this.constructor.updateCategoryProductCount(this.category);
});

// Ensure virtuals are serialized
ProductSchema.set('toJSON', { virtuals: true });
ProductSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('Product', ProductSchema);
