const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Lab = require('../models/Lab');
const Package = require('../models/Package');
const auth = require('../middleware/auth');

// Add test to cart
router.post('/add', auth.verifyToken, async (req, res) => {
    try {
        const { labId, testId, discountedPrice } = req.body;
        const userId = req.user.id;

        if (!labId || !testId) {
            return res.status(400).json({
                success: false,
                message: 'Lab ID and Test ID are required',
            });
        }

        // Find user
        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found',
            });
        }

        // Find lab to get test details
        const lab = await Lab.findById(labId);
        if (!lab) {
            return res.status(404).json({
                success: false,
                message: 'Lab not found',
            });
        }

        // Find the test in the lab's tests
        const test = lab.tests.find(t => t._id.toString() === testId);
        if (!test) {
            return res.status(404).json({
                success: false,
                message: 'Test not found in this lab',
            });
        }

        // Use discounted price if provided, otherwise use original price
        const priceToUse = discountedPrice ? parseInt(discountedPrice) : test.price;

        // Add to cart with the appropriate price
        await user.addToCart(labId, {
            _id: test._id,
            name: test.name,
            code: test.code,
            category: test.category,
            price: priceToUse,
            originalPrice: test.price, // Keep original price for reference
        });

        res.json({
            success: true,
            message: 'Test added to cart',
            data: {
                cart: user.cart,
            },
        });
    } catch (error) {
        console.error('Add to cart error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
        });
    }
});

// Add a whole Package (bundle of that lab's tests) to cart
router.post('/add-package', auth.verifyToken, async (req, res) => {
    try {
        const { labId, packageId } = req.body;
        const userId = req.user.id;

        if (!labId || !packageId) {
            return res.status(400).json({
                success: false,
                message: 'Lab ID and Package ID are required',
            });
        }

        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        const lab = await Lab.findById(labId);
        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }

        const pkg = await Package.findOne({ _id: packageId, labId, isActive: true });
        if (!pkg) {
            return res.status(404).json({ success: false, message: 'Package not found' });
        }

        // Re-resolve the package's tests against the lab's current test list -
        // a test may have been edited or removed since the package was created.
        const testIdSet = new Set(pkg.testIds.map((id) => String(id)));
        const tests = lab.tests.filter((t) => testIdSet.has(String(t._id)));
        if (tests.length !== pkg.testIds.length) {
            return res.status(400).json({
                success: false,
                message: 'This package is no longer available - one of its tests was removed',
            });
        }

        await user.addPackageToCart(labId, pkg, tests);

        res.json({
            success: true,
            message: 'Package added to cart',
            data: { cart: user.cart },
        });
    } catch (error) {
        console.error('Add package to cart error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Remove test from cart
router.delete('/remove/:testId', auth.verifyToken, async (req, res) => {
    try {
        const { testId } = req.params;
        const userId = req.user.id;

        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found',
            });
        }

        await user.removeFromCart(testId);

        res.json({
            success: true,
            message: 'Test removed from cart',
            data: {
                cart: user.cart,
            },
        });
    } catch (error) {
        console.error('Remove from cart error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
        });
    }
});

// Get cart
router.get('/', auth.verifyToken, async (req, res) => {
    try {
        const userId = req.user.id;

        const user = await User.findById(userId).populate('cart.labId');
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found',
            });
        }

        res.json({
            success: true,
            data: {
                cart: user.cart,
            },
        });
    } catch (error) {
        console.error('Get cart error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
        });
    }
});

// Clear cart
router.delete('/clear', auth.verifyToken, async (req, res) => {
    try {
        const userId = req.user.id;

        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found',
            });
        }

        await user.clearCart();

        res.json({
            success: true,
            message: 'Cart cleared',
            data: {
                cart: user.cart,
            },
        });
    } catch (error) {
        console.error('Clear cart error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
        });
    }
});

// Set prescription image in cart
router.post('/prescription', auth.verifyToken, async (req, res) => {
    try {
        const { imageUrl } = req.body;
        const userId = req.user.id;

        if (!imageUrl) {
            return res.status(400).json({
                success: false,
                message: 'Image URL is required',
            });
        }

        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found',
            });
        }

        await user.setCartPrescription(imageUrl);

        res.json({
            success: true,
            message: 'Prescription added to cart',
            data: {
                cart: user.cart,
            },
        });
    } catch (error) {
        console.error('Set prescription error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
        });
    }
});

// Remove prescription from cart
router.delete('/prescription', auth.verifyToken, async (req, res) => {
    try {
        const userId = req.user.id;

        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found',
            });
        }

        await user.removeCartPrescription();

        res.json({
            success: true,
            message: 'Prescription removed from cart',
            data: {
                cart: user.cart,
            },
        });
    } catch (error) {
        console.error('Remove prescription error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
        });
    }
});

module.exports = router;
