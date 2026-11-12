const express = require('express');
const router = express.Router();
const Category = require('../../models/Category');
const Product = require('../../models/Product');
const ShopOrder = require('../../models/ShopOrder');
const auth = require('./middleware');
const { r2SingleUpload, r2ArrayUpload } = require('../../middleware/r2Upload');
const r2Service = require('../../services/r2Service');

// R2 upload middleware for shop images
const uploadCategoryImage = r2SingleUpload('shop', 'image', 'category-');
const uploadProductImages = r2ArrayUpload('shop', 'images', 5, 'product-');

// ==================== CATEGORY ROUTES ====================

/**
 * GET /api/admin/shop/categories
 * Get all categories
 */
router.get('/categories', auth, async (req, res) => {
    try {
        const { status, search, page = 1, limit = 20 } = req.query;
        
        const query = {};
        if (status) query.status = status;
        if (search) {
            query.$or = [
                { 'name.en': { $regex: search, $options: 'i' } },
                { 'name.ar': { $regex: search, $options: 'i' } },
                { 'name.ku': { $regex: search, $options: 'i' } },
            ];
        }
        
        const categories = await Category.find(query)
            .sort({ displayOrder: 1, createdAt: -1 })
            .skip((page - 1) * limit)
            .limit(parseInt(limit))
            .populate('createdBy', 'name');
            
        const total = await Category.countDocuments(query);
        
        res.json({
            success: true,
            data: categories,
            pagination: {
                page: parseInt(page),
                limit: parseInt(limit),
                total,
                pages: Math.ceil(total / limit),
            },
        });
    } catch (error) {
        console.error('Get categories error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch categories',
        });
    }
});

/**
 * GET /api/admin/shop/categories/:id
 * Get single category
 */
router.get('/categories/:id', auth, async (req, res) => {
    try {
        const category = await Category.findById(req.params.id)
            .populate('createdBy', 'name');
            
        if (!category) {
            return res.status(404).json({
                success: false,
                message: 'Category not found',
            });
        }
        
        res.json({
            success: true,
            data: category,
        });
    } catch (error) {
        console.error('Get category error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch category',
        });
    }
});

/**
 * POST /api/admin/shop/categories
 * Create new category
 */
router.post('/categories', auth, ...uploadCategoryImage, async (req, res) => {
    try {
        const { nameEn, nameAr, nameKu, descriptionEn, descriptionAr, descriptionKu, displayOrder, status } = req.body;
        
        const category = new Category({
            name: {
                en: nameEn,
                ar: nameAr,
                ku: nameKu,
            },
            description: {
                en: descriptionEn || '',
                ar: descriptionAr || '',
                ku: descriptionKu || '',
            },
            image: req.file && req.file.r2Url ? req.file.r2Url : null,
            displayOrder: displayOrder || 0,
            status: status || 'active',
            createdBy: req.user._id,
        });
        
        await category.save();
        
        res.status(201).json({
            success: true,
            message: 'Category created successfully',
            data: category,
        });
    } catch (error) {
        console.error('Create category error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to create category',
        });
    }
});

/**
 * PUT /api/admin/shop/categories/:id
 * Update category
 */
router.put('/categories/:id', auth, ...uploadCategoryImage, async (req, res) => {
    try {
        const { nameEn, nameAr, nameKu, descriptionEn, descriptionAr, descriptionKu, displayOrder, status } = req.body;
        
        const category = await Category.findById(req.params.id);
        if (!category) {
            return res.status(404).json({
                success: false,
                message: 'Category not found',
            });
        }
        
        category.name = {
            en: nameEn,
            ar: nameAr,
            ku: nameKu,
        };
        category.description = {
            en: descriptionEn || '',
            ar: descriptionAr || '',
            ku: descriptionKu || '',
        };
        if (req.file && req.file.r2Url) {
            // Delete old image from R2 if exists
            if (category.image) {
                await r2Service.deleteFile(category.image);
            }
            category.image = req.file.r2Url;
        }
        if (displayOrder !== undefined) category.displayOrder = displayOrder;
        if (status) category.status = status;
        
        await category.save();
        
        res.json({
            success: true,
            message: 'Category updated successfully',
            data: category,
        });
    } catch (error) {
        console.error('Update category error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update category',
        });
    }
});

/**
 * DELETE /api/admin/shop/categories/:id
 * Delete category
 */
router.delete('/categories/:id', auth, async (req, res) => {
    try {
        const category = await Category.findById(req.params.id);
        if (!category) {
            return res.status(404).json({
                success: false,
                message: 'Category not found',
            });
        }
        
        // Check if category has products
        const productCount = await Product.countDocuments({ category: category._id });
        if (productCount > 0) {
            return res.status(400).json({
                success: false,
                message: `Cannot delete category with ${productCount} products. Please reassign or delete products first.`,
            });
        }
        
        // Delete image from R2 if exists
        if (category.image) {
            await r2Service.deleteFile(category.image);
        }
        
        await Category.findByIdAndDelete(req.params.id);
        
        res.json({
            success: true,
            message: 'Category deleted successfully',
        });
    } catch (error) {
        console.error('Delete category error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to delete category',
        });
    }
});

// ==================== PRODUCT ROUTES ====================

/**
 * GET /api/admin/shop/products
 * Get all products with filtering
 */
router.get('/products', auth, async (req, res) => {
    try {
        const { status, category, search, featured, page = 1, limit = 20 } = req.query;
        
        const query = {};
        if (status) query.status = status;
        if (category) query.category = category;
        if (featured === 'true') query.isFeatured = true;
        if (search) {
            query.$or = [
                { 'name.en': { $regex: search, $options: 'i' } },
                { 'name.ar': { $regex: search, $options: 'i' } },
                { 'name.ku': { $regex: search, $options: 'i' } },
                { tags: { $regex: search, $options: 'i' } },
            ];
        }
        
        const products = await Product.find(query)
            .sort({ isFeatured: -1, createdAt: -1 })
            .skip((page - 1) * limit)
            .limit(parseInt(limit))
            .populate('category', 'name slug')
            .populate('createdBy', 'name');
            
        const total = await Product.countDocuments(query);
        
        res.json({
            success: true,
            data: products,
            pagination: {
                page: parseInt(page),
                limit: parseInt(limit),
                total,
                pages: Math.ceil(total / limit),
            },
        });
    } catch (error) {
        console.error('Get products error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch products',
        });
    }
});

/**
 * GET /api/admin/shop/products/:id
 * Get single product
 */
router.get('/products/:id', auth, async (req, res) => {
    try {
        const product = await Product.findById(req.params.id)
            .populate('category', 'name slug')
            .populate('createdBy', 'name');
            
        if (!product) {
            return res.status(404).json({
                success: false,
                message: 'Product not found',
            });
        }
        
        res.json({
            success: true,
            data: product,
        });
    } catch (error) {
        console.error('Get product error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch product',
        });
    }
});

/**
 * POST /api/admin/shop/products
 * Create new product
 */
router.post('/products', auth, ...uploadProductImages, async (req, res) => {
    try {
        const {
            nameEn, nameAr, nameKu,
            descriptionEn, descriptionAr, descriptionKu,
            shortDescriptionEn, shortDescriptionAr, shortDescriptionKu,
            category, price, compareAtPrice, currency,
            trackInventory, quantity, allowBackorder, lowStockThreshold,
            status, isFeatured, tags
        } = req.body;
        
        // Validate category exists
        const categoryExists = await Category.findById(category);
        if (!categoryExists) {
            return res.status(400).json({
                success: false,
                message: 'Invalid category',
            });
        }
        
        const images = (req.files || []).map((file, index) => ({
            url: file.r2Url,
            isPrimary: index === 0,
        }));
        
        const product = new Product({
            name: {
                en: nameEn,
                ar: nameAr,
                ku: nameKu,
            },
            description: {
                en: descriptionEn || '',
                ar: descriptionAr || '',
                ku: descriptionKu || '',
            },
            shortDescription: {
                en: shortDescriptionEn || '',
                ar: shortDescriptionAr || '',
                ku: shortDescriptionKu || '',
            },
            category,
            images,
            price: parseFloat(price),
            compareAtPrice: compareAtPrice ? parseFloat(compareAtPrice) : null,
            currency: currency || 'IQD',
            inventory: {
                trackInventory: trackInventory === 'true',
                quantity: parseInt(quantity) || 0,
                allowBackorder: allowBackorder === 'true',
                lowStockThreshold: parseInt(lowStockThreshold) || 5,
            },
            status: status || 'draft',
            isFeatured: isFeatured === 'true',
            tags: tags ? tags.split(',').map(t => t.trim()) : [],
            createdBy: req.user._id,
        });
        
        await product.save();
        
        res.status(201).json({
            success: true,
            message: 'Product created successfully',
            data: product,
        });
    } catch (error) {
        console.error('Create product error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to create product',
        });
    }
});

/**
 * PUT /api/admin/shop/products/:id
 * Update product
 */
router.put('/products/:id', auth, ...uploadProductImages, async (req, res) => {
    try {
        const product = await Product.findById(req.params.id);
        if (!product) {
            return res.status(404).json({
                success: false,
                message: 'Product not found',
            });
        }
        
        const {
            nameEn, nameAr, nameKu,
            descriptionEn, descriptionAr, descriptionKu,
            shortDescriptionEn, shortDescriptionAr, shortDescriptionKu,
            category, price, compareAtPrice, currency,
            trackInventory, quantity, allowBackorder, lowStockThreshold,
            status, isFeatured, tags, removeImages, primaryImage
        } = req.body;
        
        // Update basic fields
        product.name = { en: nameEn, ar: nameAr, ku: nameKu };
        product.description = { en: descriptionEn || '', ar: descriptionAr || '', ku: descriptionKu || '' };
        product.shortDescription = { en: shortDescriptionEn || '', ar: shortDescriptionAr || '', ku: shortDescriptionKu || '' };
        
        if (category) {
            const categoryExists = await Category.findById(category);
            if (!categoryExists) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid category',
                });
            }
            product.category = category;
        }
        
        product.price = parseFloat(price);
        product.compareAtPrice = compareAtPrice ? parseFloat(compareAtPrice) : null;
        product.currency = currency || 'IQD';
        
        product.inventory = {
            trackInventory: trackInventory === 'true',
            quantity: parseInt(quantity) || 0,
            allowBackorder: allowBackorder === 'true',
            lowStockThreshold: parseInt(lowStockThreshold) || 5,
        };
        
        product.status = status || product.status;
        product.isFeatured = isFeatured === 'true';
        product.tags = tags ? tags.split(',').map(t => t.trim()) : [];
        
        // Handle image removal from R2
        if (removeImages) {
            const imagesToRemove = JSON.parse(removeImages);
            product.images = product.images.filter(img => {
                if (imagesToRemove.includes(img.url)) {
                    // Delete from R2
                    r2Service.deleteFile(img.url).catch(err => console.error('R2 delete error:', err));
                    return false;
                }
                return true;
            });
        }
        
        // Add new images from R2
        if (req.files && req.files.length > 0) {
            const newImages = req.files.map(file => ({
                url: file.r2Url,
                isPrimary: false,
            }));
            product.images.push(...newImages);
        }
        
        // Set primary image
        if (primaryImage) {
            product.images = product.images.map(img => ({
                ...img.toObject(),
                isPrimary: img.url === primaryImage,
            }));
        } else if (product.images.length > 0 && !product.images.some(img => img.isPrimary)) {
            product.images[0].isPrimary = true;
        }
        
        await product.save();
        
        res.json({
            success: true,
            message: 'Product updated successfully',
            data: product,
        });
    } catch (error) {
        console.error('Update product error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update product',
        });
    }
});

/**
 * DELETE /api/admin/shop/products/:id
 * Delete product
 */
router.delete('/products/:id', auth, async (req, res) => {
    try {
        const product = await Product.findById(req.params.id);
        if (!product) {
            return res.status(404).json({
                success: false,
                message: 'Product not found',
            });
        }
        
        // Delete all images from R2
        for (const img of product.images) {
            await r2Service.deleteFile(img.url);
        }
        
        await Product.findByIdAndDelete(req.params.id);
        
        res.json({
            success: true,
            message: 'Product deleted successfully',
        });
    } catch (error) {
        console.error('Delete product error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to delete product',
        });
    }
});

// ==================== SHOP ORDER ROUTES ====================

/**
 * GET /api/admin/shop/orders
 * Get all shop orders
 */
router.get('/orders', auth, async (req, res) => {
    try {
        const { status, search, startDate, endDate, page = 1, limit = 20 } = req.query;
        
        const query = {};
        if (status && status !== 'all') query.status = status;
        if (search) {
            query.$or = [
                { orderNumber: { $regex: search, $options: 'i' } },
                { 'customer.name': { $regex: search, $options: 'i' } },
                { 'customer.phone': { $regex: search, $options: 'i' } },
            ];
        }
        if (startDate) {
            query.createdAt = { ...query.createdAt, $gte: new Date(startDate) };
        }
        if (endDate) {
            const end = new Date(endDate);
            end.setHours(23, 59, 59, 999);
            query.createdAt = { ...query.createdAt, $lte: end };
        }
        
        const orders = await ShopOrder.find(query)
            .sort({ createdAt: -1 })
            .skip((page - 1) * limit)
            .limit(parseInt(limit));
            
        const total = await ShopOrder.countDocuments(query);
        
        res.json({
            success: true,
            data: orders,
            pagination: {
                page: parseInt(page),
                limit: parseInt(limit),
                total,
                pages: Math.ceil(total / limit),
            },
        });
    } catch (error) {
        console.error('Get shop orders error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch orders',
            error: error.message,
        });
    }
});

/**
 * GET /api/admin/shop/orders/statistics
 * Get shop order statistics
 */
router.get('/orders/statistics', auth, async (req, res) => {
    try {
        const stats = await ShopOrder.getStatistics();
        
        // Get today's stats
        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);
        const todayStats = await ShopOrder.getStatistics(todayStart, new Date());
        
        // Get this month's stats
        const monthStart = new Date();
        monthStart.setDate(1);
        monthStart.setHours(0, 0, 0, 0);
        const monthStats = await ShopOrder.getStatistics(monthStart, new Date());
        
        res.json({
            success: true,
            data: {
                all: stats,
                today: todayStats,
                thisMonth: monthStats,
            },
        });
    } catch (error) {
        console.error('Get shop order statistics error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch statistics',
        });
    }
});

/**
 * GET /api/admin/shop/orders/:id
 * Get single shop order
 */
router.get('/orders/:id', auth, async (req, res) => {
    try {
        const order = await ShopOrder.findById(req.params.id)
            .populate('items.productId', 'name images slug')
            .populate('customer.userId', 'name email')
            .populate('statusHistory.changedBy', 'name');
            
        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found',
            });
        }
        
        res.json({
            success: true,
            data: order,
        });
    } catch (error) {
        console.error('Get shop order error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch order',
        });
    }
});

/**
 * PUT /api/admin/shop/orders/:id/status
 * Update shop order status
 */
router.put('/orders/:id/status', auth, async (req, res) => {
    try {
        const { status, notes } = req.body;
        
        if (!['pending', 'processing', 'done', 'cancelled'].includes(status)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid status',
            });
        }
        
        const order = await ShopOrder.findById(req.params.id);
        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found',
            });
        }
        
        await order.updateStatus(status, req.user._id, notes);
        
        res.json({
            success: true,
            message: 'Order status updated successfully',
            data: order,
        });
    } catch (error) {
        console.error('Update shop order status error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update order status',
        });
    }
});

/**
 * POST /api/admin/shop/orders/:id/notes
 * Add a new admin note to order
 */
router.post('/orders/:id/notes', auth, async (req, res) => {
    try {
        const { note } = req.body;

        if (!note || !note.trim()) {
            return res.status(400).json({
                success: false,
                message: 'Note content is required',
            });
        }

        const newNote = {
            note: note.trim(),
            addedAt: new Date(),
            addedBy: req.user?.id,
        };

        // Use direct MongoDB update to bypass Mongoose validation issues
        const result = await ShopOrder.updateOne(
            { _id: req.params.id },
            [
                {
                    $set: {
                        adminNotes: {
                            $cond: {
                                if: { $isArray: "$adminNotes" },
                                then: { $concatArrays: ["$adminNotes", [newNote]] },
                                else: [newNote]
                            }
                        }
                    }
                }
            ]
        );

        if (result.matchedCount === 0) {
            return res.status(404).json({
                success: false,
                message: 'Order not found',
            });
        }

        // Fetch the updated order to return
        const order = await ShopOrder.findById(req.params.id);

        res.json({
            success: true,
            message: 'Note added successfully',
            data: order,
        });
    } catch (error) {
        console.error('Add shop order note error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to add note',
        });
    }
});

/**
 * DELETE /api/admin/shop/orders/:id/notes/:noteId
 * Delete a specific admin note from order
 */
router.delete('/orders/:id/notes/:noteId', auth, async (req, res) => {
    try {
        const { id, noteId } = req.params;

        // Use direct MongoDB update to pull the note by its _id or index
        // First try to find and get the note index
        const order = await ShopOrder.findById(id).lean();

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found',
            });
        }

        // Handle old string format - convert to array first
        let adminNotes = order.adminNotes || [];
        if (typeof adminNotes === 'string') {
            adminNotes = adminNotes.trim() ? [{
                _id: new mongoose.Types.ObjectId(),
                note: adminNotes,
                addedAt: order.createdAt || new Date()
            }] : [];
        }

        // Find the note by index (noteId is passed as string index)
        const noteIndex = parseInt(noteId);
        if (noteIndex < 0 || noteIndex >= adminNotes.length) {
            return res.status(404).json({
                success: false,
                message: 'Note not found',
            });
        }

        // Remove the note at the specified index
        adminNotes.splice(noteIndex, 1);

        // Update the order
        await ShopOrder.updateOne(
            { _id: id },
            { $set: { adminNotes } }
        );

        res.json({
            success: true,
            message: 'Note deleted successfully',
        });
    } catch (error) {
        console.error('Delete shop order note error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to delete note',
        });
    }
});

/**
 * PUT /api/admin/shop/orders/:id/notes
 * Update admin notes on order (replaces all notes)
 */
router.put('/orders/:id/notes', auth, async (req, res) => {
    try {
        const { notes } = req.body;

        const order = await ShopOrder.findById(req.params.id);

        if (!order) {
            return res.status(404).json({
                success: false,
                message: 'Order not found',
            });
        }

        // Support both string (backward compatibility) and array formats
        if (typeof notes === 'string') {
            // Convert string to single-note array
            order.adminNotes = [{
                note: notes,
                addedAt: new Date(),
                addedBy: req.user?.id,
            }];
        } else if (Array.isArray(notes)) {
            // Use the array as-is
            order.adminNotes = notes;
        } else {
            return res.status(400).json({
                success: false,
                message: 'Invalid notes format',
            });
        }

        await order.save();

        res.json({
            success: true,
            message: 'Notes updated successfully',
            data: order,
        });
    } catch (error) {
        console.error('Update shop order notes error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update notes',
        });
    }
});

module.exports = router;
