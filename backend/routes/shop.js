const express = require('express');
const router = express.Router();
const Category = require('../models/Category');
const Product = require('../models/Product');
const ShopOrder = require('../models/ShopOrder');
const { sendOtp, verifyOtpLocal } = require('../services/otpService');
const telegramService = require('../services/telegramService');

// Helper function to format image URL
function formatImageUrl(imageUrl) {
    if (!imageUrl) return '/images/noimage.jpg';
    // If image doesn't start with / or http, add uploads/shop/ prefix
    if (!imageUrl.startsWith('/') && !imageUrl.startsWith('http')) {
        return `/uploads/shop/${imageUrl}`;
    }
    return imageUrl;
}

// Helper function to format product images array
function formatProductImages(product) {
    if (!product.images || product.images.length === 0) {
        return [{ url: '/images/noimage.jpg', alt: '', isPrimary: false }];
    }
    return product.images.map(img => ({
        ...img,
        url: formatImageUrl(img.url)
    }));
}

// ==================== PUBLIC CATEGORY ROUTES ====================

/**
 * GET /api/shop/categories
 * Get all active categories
 */
router.get('/categories', async (req, res) => {
    try {
        const categories = await Category.find({ status: 'active' })
            .sort({ displayOrder: 1 })
            .select('name description image slug productCount')
            .lean();

        // Format image URLs for categories
        const formattedCategories = categories.map(cat => ({
            ...cat,
            image: formatImageUrl(cat.image)
        }));

        res.json({
            success: true,
            data: formattedCategories,
        });
    } catch (error) {
        console.error('Get public categories error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch categories',
        });
    }
});

/**
 * GET /api/shop/categories/:slug
 * Get category by slug with products
 */
router.get('/categories/:slug', async (req, res) => {
    try {
        const category = await Category.findOne({
            slug: req.params.slug,
            status: 'active'
        })
        .lean();

        if (!category) {
            return res.status(404).json({
                success: false,
                message: 'Category not found',
            });
        }

        const products = await Product.find({
            category: category._id,
            status: 'active'
        })
        .sort({ isFeatured: -1, createdAt: -1 })
        .select('name shortDescription images price compareAtPrice slug isFeatured')
        .lean();

        // Format category image
        const formattedCategory = {
            ...category,
            image: formatImageUrl(category.image)
        };

        // Format product images
        const formattedProducts = products.map(product => ({
            ...product,
            images: formatProductImages(product)
        }));

        res.json({
            success: true,
            data: {
                category: formattedCategory,
                products: formattedProducts,
            },
        });
    } catch (error) {
        console.error('Get category by slug error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch category',
        });
    }
});

// ==================== PUBLIC PRODUCT ROUTES ====================

/**
 * GET /api/shop/products
 * Get all active products with optional filtering
 */
router.get('/products', async (req, res) => {
    try {
        const { category, featured, search, page = 1, limit = 20, sort = 'newest' } = req.query;
        
        const query = { status: 'active' };
        if (category) {
            const cat = await Category.findOne({ slug: category, status: 'active' });
            if (cat) query.category = cat._id;
        }
        if (featured === 'true') query.isFeatured = true;
        if (search) {
            query.$or = [
                { 'name.en': { $regex: search, $options: 'i' } },
                { 'name.ar': { $regex: search, $options: 'i' } },
                { 'name.ku': { $regex: search, $options: 'i' } },
                { tags: { $regex: search, $options: 'i' } },
            ];
        }
        
        // Sorting options
        let sortOption = { isFeatured: -1, createdAt: -1 };
        switch (sort) {
            case 'price_asc':
                sortOption = { price: 1 };
                break;
            case 'price_desc':
                sortOption = { price: -1 };
                break;
            case 'popular':
                sortOption = { 'stats.totalSold': -1 };
                break;
            case 'newest':
            default:
                sortOption = { isFeatured: -1, createdAt: -1 };
        }
        
        const products = await Product.find(query)
            .sort(sortOption)
            .skip((page - 1) * limit)
            .limit(parseInt(limit))
            .populate('category', 'name slug')
            .select('name shortDescription images price compareAtPrice slug isFeatured category inventory')
            .lean();

        // Format image URLs for each product
        const formattedProducts = products.map(product => ({
            ...product,
            images: formatProductImages(product)
        }));

        const total = await Product.countDocuments(query);

        res.json({
            success: true,
            data: formattedProducts,
            pagination: {
                page: parseInt(page),
                limit: parseInt(limit),
                total,
                totalPages: Math.ceil(total / limit),
            },
        });
    } catch (error) {
        console.error('Get public products error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch products',
        });
    }
});

/**
 * GET /api/shop/products/featured
 * Get featured products
 */
router.get('/products/featured', async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 8;

        const products = await Product.find({
            status: 'active',
            isFeatured: true
        })
        .sort({ createdAt: -1 })
        .limit(limit)
        .populate('category', 'name slug')
        .select('name shortDescription images price compareAtPrice slug category')
        .lean();

        // Format image URLs for each product
        const formattedProducts = products.map(product => ({
            ...product,
            images: formatProductImages(product)
        }));

        res.json({
            success: true,
            data: formattedProducts,
        });
    } catch (error) {
        console.error('Get featured products error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch featured products',
        });
    }
});

/**
 * GET /api/shop/products/:slug
 * Get single product by slug
 */
router.get('/products/:slug', async (req, res) => {
    try {
        const product = await Product.findOne({
            slug: req.params.slug,
            status: 'active'
        })
        .populate('category', 'name slug')
        .lean();

        if (!product) {
            return res.status(404).json({
                success: false,
                message: 'Product not found',
            });
        }

        // Increment view count
        await Product.findByIdAndUpdate(product._id, {
            $inc: { 'stats.viewCount': 1 }
        });

        // Format product images
        const formattedProduct = {
            ...product,
            images: formatProductImages(product)
        };

        // Get related products from same category
        const relatedProducts = await Product.find({
            category: product.category._id,
            status: 'active',
            _id: { $ne: product._id }
        })
        .limit(4)
        .select('name images price compareAtPrice slug')
        .lean();

        // Format related product images
        const formattedRelatedProducts = relatedProducts.map(p => ({
            ...p,
            images: formatProductImages(p)
        }));

        res.json({
            success: true,
            data: {
                product: formattedProduct,
                relatedProducts: formattedRelatedProducts,
            },
        });
    } catch (error) {
        console.error('Get product by slug error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch product',
        });
    }
});

// ==================== CART & CHECKOUT ROUTES ====================

/**
 * POST /api/shop/cart/validate
 * Validate cart items (check stock, prices)
 */
router.post('/cart/validate', async (req, res) => {
    try {
        const { items } = req.body;
        
        if (!items || !Array.isArray(items) || items.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Cart is empty',
            });
        }
        
        const validatedItems = [];
        const errors = [];
        let subtotal = 0;
        
        for (const item of items) {
            const product = await Product.findById(item.productId)
                .select('name images price inventory status')
                .lean();

            if (!product) {
                errors.push({
                    productId: item.productId,
                    error: 'Product not found',
                });
                continue;
            }

            if (product.status !== 'active') {
                errors.push({
                    productId: item.productId,
                    error: 'Product is no longer available',
                });
                continue;
            }

            // Check inventory
            if (product.inventory.trackInventory &&
                !product.inventory.allowBackorder &&
                product.inventory.quantity < item.quantity) {
                errors.push({
                    productId: item.productId,
                    error: `Only ${product.inventory.quantity} items available`,
                    availableQuantity: product.inventory.quantity,
                });
                continue;
            }

            const itemSubtotal = product.price * item.quantity;
            subtotal += itemSubtotal;

            // Get first image with formatted URL
            const firstImage = product.images && product.images.length > 0
                ? formatImageUrl(product.images[0].url)
                : null;

            validatedItems.push({
                productId: product._id,
                name: product.name,
                image: firstImage,
                price: product.price,
                quantity: item.quantity,
                subtotal: itemSubtotal,
            });
        }
        
        res.json({
            success: true,
            data: {
                items: validatedItems,
                errors,
                pricing: {
                    subtotal,
                    deliveryFee: 0, // Can be calculated based on location
                    discount: 0,
                    total: subtotal,
                    currency: 'IQD',
                },
            },
        });
    } catch (error) {
        console.error('Validate cart error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to validate cart',
        });
    }
});

/**
 * POST /api/shop/checkout/send-otp
 * Send OTP for phone verification during checkout
 */
router.post('/checkout/send-otp', async (req, res) => {
    try {
        const { phone } = req.body;
        
        if (!phone) {
            return res.status(400).json({
                success: false,
                message: 'Phone number is required',
            });
        }
        
        const result = await sendOtp(phone);
        
        if (result.success) {
            res.json({
                success: true,
                message: 'OTP sent successfully',
                messageId: result.messageId,
            });
        } else {
            res.status(400).json({
                success: false,
                message: result.message || 'Failed to send OTP',
            });
        }
    } catch (error) {
        console.error('Send checkout OTP error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to send OTP',
        });
    }
});

/**
 * POST /api/shop/checkout/verify-otp
 * Verify OTP during checkout
 */
router.post('/checkout/verify-otp', async (req, res) => {
    try {
        const { phone, code } = req.body;

        if (!phone || !code) {
            return res.status(400).json({
                success: false,
                message: 'Phone number and OTP code are required',
            });
        }

        const result = verifyOtpLocal({ phone, code });
        
        if (result.success) {
            res.json({
                success: true,
                message: 'Phone verified successfully',
            });
        } else {
            res.status(400).json({
                success: false,
                message: result.message || 'Invalid OTP code',
            });
        }
    } catch (error) {
        console.error('Verify checkout OTP error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to verify OTP',
        });
    }
});

/**
 * POST /api/shop/checkout/place-order
 * Place order after phone verification
 */
router.post('/checkout/place-order', async (req, res) => {
    try {
        const {
            items,
            customer,
            deliveryAddress,
            messageId,
        } = req.body;
        
        // Validate required fields
        if (!items || items.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Cart is empty',
            });
        }
        
        if (!customer?.name || !customer?.phone) {
            return res.status(400).json({
                success: false,
                message: 'Customer name and phone are required',
            });
        }
        
        if (!deliveryAddress?.address) {
            return res.status(400).json({
                success: false,
                message: 'Delivery address is required',
            });
        }
        
        // Validate and prepare order items
        const orderItems = [];
        let subtotal = 0;
        
        for (const item of items) {
            const product = await Product.findById(item.productId)
                .select('name images price inventory status')
                .lean();

            if (!product || product.status !== 'active') {
                return res.status(400).json({
                    success: false,
                    message: `Product ${item.productId} is no longer available`,
                });
            }

            // Check and update inventory
            if (product.inventory.trackInventory) {
                if (!product.inventory.allowBackorder &&
                    product.inventory.quantity < item.quantity) {
                    return res.status(400).json({
                        success: false,
                        message: `Insufficient stock for ${product.name.en}`,
                    });
                }

                // Decrease inventory
                await Product.findByIdAndUpdate(item.productId, {
                    $inc: {
                        'inventory.quantity': -item.quantity,
                        'stats.totalSold': item.quantity
                    }
                });
            }

            const itemSubtotal = product.price * item.quantity;
            subtotal += itemSubtotal;

            // Get first image with formatted URL
            const firstImage = product.images && product.images.length > 0
                ? formatImageUrl(product.images[0].url)
                : null;

            orderItems.push({
                productId: product._id,
                name: product.name,
                image: firstImage,
                price: product.price,
                quantity: item.quantity,
                subtotal: itemSubtotal,
            });
        }
        
        // Create order
        const order = new ShopOrder({
            customer: {
                name: customer.name,
                phone: customer.phone,
                phoneVerified: true,
                verification: {
                    messageId,
                    verifiedAt: new Date(),
                },
            },
            deliveryAddress: {
                address: deliveryAddress.address,
                city: deliveryAddress.city || '',
                notes: deliveryAddress.notes || '',
            },
            items: orderItems,
            pricing: {
                subtotal,
                deliveryFee: 0,
                discount: 0,
                total: subtotal,
                currency: 'IQD',
            },
            status: 'pending',
            payment: {
                method: 'cash_on_delivery',
                status: 'pending',
            },
        });
        
        await order.save();

        // Update product revenue stats
        for (const item of orderItems) {
            await Product.findByIdAndUpdate(item.productId, {
                $inc: { 'stats.totalRevenue': item.subtotal }
            });
        }

        // Send Telegram notification asynchronously (don't wait for it)
        telegramService.sendNewShopOrderNotification(order).catch(err => {
            console.error('Failed to send Telegram notification for shop order:', err);
        });

        res.status(201).json({
            success: true,
            message: 'Order placed successfully',
            data: {
                orderNumber: order.orderNumber,
                orderId: order._id,
                total: order.pricing.total,
            },
        });
    } catch (error) {
        console.error('Place order error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to place order',
        });
    }
});

/**
 * GET /api/shop/orders/:orderNumber
 * Get order status by order number (public tracking)
 */
router.get('/orders/:orderNumber', async (req, res) => {
    try {
        const order = await ShopOrder.findOne({ 
            orderNumber: req.params.orderNumber 
        })
        .select('orderNumber status items pricing customer deliveryAddress createdAt statusHistory');
        
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
        console.error('Get order status error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch order',
        });
    }
});

module.exports = router;
