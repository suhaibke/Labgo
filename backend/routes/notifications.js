const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Notification = require('../models/Notification');
const { verifyToken } = require('../middleware/auth');

// Register FCM token
router.post('/register-token', verifyToken, async (req, res) => {
  try {
    const { fcmToken, platform } = req.body;
    const userId = req.user._id;

    if (!fcmToken || !platform) {
      return res.status(400).json({
        success: false,
        message: 'fcmToken and platform required'
      });
    }

    if (!['ios', 'android'].includes(platform)) {
      return res.status(400).json({
        success: false,
        message: 'platform must be ios or android'
      });
    }

    // Remove token from any other user (device switch scenario)
    await User.updateMany(
      { _id: { $ne: userId } },
      { $pull: { fcmTokens: { token: fcmToken } } }
    );

    // Remove existing token from current user (to avoid duplicates)
    await User.findByIdAndUpdate(userId, {
      $pull: { fcmTokens: { token: fcmToken } }
    });

    // Add new token to current user
    await User.findByIdAndUpdate(userId, {
      $push: {
        fcmTokens: {
          token: fcmToken,
          platform,
          createdAt: new Date()
        }
      }
    });

    console.log(`FCM token registered for user ${userId} (${platform})`);

    res.json({
      success: true,
      message: 'FCM token registered successfully'
    });
  } catch (error) {
    console.error('FCM register error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to register FCM token'
    });
  }
});

// Unregister FCM token (on logout)
router.post('/unregister-token', verifyToken, async (req, res) => {
  try {
    const { fcmToken } = req.body;
    const userId = req.user._id;

    if (!fcmToken) {
      return res.status(400).json({
        success: false,
        message: 'fcmToken required'
      });
    }

    await User.findByIdAndUpdate(userId, {
      $pull: { fcmTokens: { token: fcmToken } }
    });

    console.log(`FCM token unregistered for user ${userId}`);

    res.json({
      success: true,
      message: 'FCM token unregistered successfully'
    });
  } catch (error) {
    console.error('FCM unregister error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to unregister FCM token'
    });
  }
});

/**
 * GET /api/notifications
 * The current user's notification history, newest first.
 */
router.get('/', verifyToken, async (req, res) => {
  try {
    const { page = 1, limit = 30 } = req.query;
    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(50, Math.max(1, parseInt(limit, 10) || 30));

    const [notifications, total, unreadCount] = await Promise.all([
      Notification.find({ userId: req.user._id })
        .sort({ createdAt: -1 })
        .skip((pageNum - 1) * limitNum)
        .limit(limitNum),
      Notification.countDocuments({ userId: req.user._id }),
      Notification.countDocuments({ userId: req.user._id, isRead: false }),
    ]);

    res.json({
      success: true,
      data: {
        notifications,
        unreadCount,
        pagination: {
          total,
          page: pageNum,
          limit: limitNum,
          pages: Math.ceil(total / limitNum) || 1,
        },
      },
    });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({ success: false, message: 'Failed to load notifications' });
  }
});

/**
 * GET /api/notifications/unread-count
 * Lightweight count for the home page bell badge.
 */
router.get('/unread-count', verifyToken, async (req, res) => {
  try {
    const unreadCount = await Notification.countDocuments({
      userId: req.user._id,
      isRead: false,
    });
    res.json({ success: true, data: { unreadCount } });
  } catch (error) {
    console.error('Get unread count error:', error);
    res.status(500).json({ success: false, message: 'Failed to load unread count' });
  }
});

/**
 * POST /api/notifications/read-all
 * Must come before the /:id/read route so "read-all" isn't parsed as an id.
 */
router.post('/read-all', verifyToken, async (req, res) => {
  try {
    await Notification.updateMany(
      { userId: req.user._id, isRead: false },
      { $set: { isRead: true } }
    );
    res.json({ success: true, message: 'All notifications marked as read' });
  } catch (error) {
    console.error('Mark all notifications read error:', error);
    res.status(500).json({ success: false, message: 'Failed to mark notifications as read' });
  }
});

/**
 * POST /api/notifications/:id/read
 */
router.post('/:id/read', verifyToken, async (req, res) => {
  try {
    const notification = await Notification.findOneAndUpdate(
      { _id: req.params.id, userId: req.user._id },
      { $set: { isRead: true } },
      { new: true }
    );

    if (!notification) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }

    res.json({ success: true, data: { notification } });
  } catch (error) {
    console.error('Mark notification read error:', error);
    res.status(500).json({ success: false, message: 'Failed to mark notification as read' });
  }
});

module.exports = router;
