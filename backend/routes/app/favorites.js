const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const User = require('../../models/User');
const Lab = require('../../models/Lab');

const { verifyToken } = require('../../middleware/auth');

// Favorites always belong to a signed-in user
router.use(verifyToken);

// Same projection the app's lab browsing endpoints use (phone/email stay private)
const LAB_FIELDS =
    'name address city country logo specialization status operatingHours averageRating totalReviews isVerified tests totalTestsPerformed coordinates';

const isValidId = (id) => mongoose.Types.ObjectId.isValid(id);

/**
 * GET /api/app/favorites
 * Full favorite labs of the current user
 */
router.get('/', async (req, res) => {
    try {
        const user = await User.findById(req.user._id).select('favoriteLabs');
        const ids = (user && user.favoriteLabs) || [];

        const labs = await Lab.find({ _id: { $in: ids }, status: 'Active' })
            .select(LAB_FIELDS)
            .sort({ averageRating: -1, totalReviews: -1 });

        res.json({
            success: true,
            message: 'Favorites retrieved successfully',
            data: { labs, total: labs.length },
        });
    } catch (error) {
        console.error('Error fetching favorites:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching favorites',
            error: error.message,
        });
    }
});

/**
 * GET /api/app/favorites/ids
 * Lightweight id list, used by the app to paint the heart icons in lists
 */
router.get('/ids', async (req, res) => {
    try {
        const user = await User.findById(req.user._id).select('favoriteLabs');
        const ids = ((user && user.favoriteLabs) || []).map((id) => id.toString());

        res.json({
            success: true,
            message: 'Favorite ids retrieved successfully',
            data: { labIds: ids },
        });
    } catch (error) {
        console.error('Error fetching favorite ids:', error);
        res.status(500).json({
            success: false,
            message: 'Error fetching favorite ids',
            error: error.message,
        });
    }
});

/**
 * POST /api/app/favorites/:labId/toggle
 * Add the lab to favorites, or remove it if it is already there
 */
router.post('/:labId/toggle', async (req, res) => {
    try {
        const { labId } = req.params;

        if (!isValidId(labId)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid lab id',
            });
        }

        const lab = await Lab.findById(labId).select('_id');
        if (!lab) {
            return res.status(404).json({
                success: false,
                message: 'Lab not found',
            });
        }

        const user = await User.findById(req.user._id).select('favoriteLabs');
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found',
            });
        }

        const exists = (user.favoriteLabs || []).some(
            (id) => id.toString() === labId
        );

        if (exists) {
            user.favoriteLabs = user.favoriteLabs.filter(
                (id) => id.toString() !== labId
            );
        } else {
            user.favoriteLabs.push(labId);
        }

        await user.save();

        res.json({
            success: true,
            message: exists ? 'Removed from favorites' : 'Added to favorites',
            data: {
                isFavorite: !exists,
                labIds: user.favoriteLabs.map((id) => id.toString()),
            },
        });
    } catch (error) {
        console.error('Error toggling favorite:', error);
        res.status(500).json({
            success: false,
            message: 'Error toggling favorite',
            error: error.message,
        });
    }
});

/**
 * DELETE /api/app/favorites/:labId
 */
router.delete('/:labId', async (req, res) => {
    try {
        const { labId } = req.params;

        if (!isValidId(labId)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid lab id',
            });
        }

        await User.updateOne(
            { _id: req.user._id },
            { $pull: { favoriteLabs: labId } }
        );

        res.json({
            success: true,
            message: 'Removed from favorites',
        });
    } catch (error) {
        console.error('Error removing favorite:', error);
        res.status(500).json({
            success: false,
            message: 'Error removing favorite',
            error: error.message,
        });
    }
});

module.exports = router;
