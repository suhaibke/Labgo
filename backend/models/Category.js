const mongoose = require('mongoose');

const CategorySchema = new mongoose.Schema({
    // Category name (multilingual)
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

    // Category description (multilingual)
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

    // Category image/icon
    image: {
        type: String,
        default: null,
    },

    // Display order for sorting
    displayOrder: {
        type: Number,
        default: 0,
    },

    // Category status
    status: {
        type: String,
        enum: ['active', 'inactive'],
        default: 'active',
    },

    // Product count (cached for performance)
    productCount: {
        type: Number,
        default: 0,
    },

    // SEO slug
    slug: {
        type: String,
        unique: true,
        lowercase: true,
        trim: true,
    },

    // Created by admin
    createdBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
    },

}, {
    timestamps: true,
});

// Index for efficient queries
CategorySchema.index({ status: 1, displayOrder: 1 });
CategorySchema.index({ slug: 1 });

// Pre-save hook to generate slug
CategorySchema.pre('save', function(next) {
    if (this.isModified('name.en') || !this.slug) {
        this.slug = this.name.en
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/(^-|-$)/g, '');
    }
    next();
});

// Static method to get localized name
CategorySchema.methods.getLocalizedName = function(lang = 'en') {
    return this.name[lang] || this.name.en;
};

// Static method to get localized description
CategorySchema.methods.getLocalizedDescription = function(lang = 'en') {
    return this.description[lang] || this.description.en;
};

module.exports = mongoose.model('Category', CategorySchema);
