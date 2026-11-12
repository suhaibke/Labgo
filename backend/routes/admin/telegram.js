const express = require('express');
const router = express.Router();
const auth = require('../../middleware/auth');
const telegramService = require('../../services/telegramService');

// Admin middleware
const requireAdmin = async (req, res, next) => {
    if (req.user.role !== 'admin') {
        return res.status(403).json({
            success: false,
            message: 'Access denied. Admin role required.'
        });
    }
    next();
};

/**
 * Test Telegram bot connection
 * GET /api/admin/telegram/test
 */
router.get('/test', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const isConnected = await telegramService.testConnection();

        if (isConnected) {
            const botInfo = await telegramService.getBotInfo();
            res.json({
                success: true,
                message: 'Telegram bot is connected',
                data: {
                    bot: botInfo,
                    connected: true
                }
            });
        } else {
            res.status(500).json({
                success: false,
                message: 'Failed to connect to Telegram bot'
            });
        }
    } catch (error) {
        console.error('Telegram test error:', error);
        res.status(500).json({
            success: false,
            message: 'Error testing Telegram connection',
            error: error.message
        });
    }
});

/**
 * Send test message to configured users
 * POST /api/admin/telegram/test-message
 */
router.post('/test-message', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const testMessage = `🧪 <b>رسالة تجريبية</b>

هذه رسالة تجريبية من نظام لاب جو.

إذا استلمت هذه الرسالة، فإن بوت تيليجرام يعمل بشكل صحيح! ✅

تم الإرسال: ${new Date().toLocaleString('ar-IQ')}`;

        // Send to all configured users
        const NOTIFICATION_USERS = process.env.TELEGRAM_NOTIFICATION_USERS
            ? process.env.TELEGRAM_NOTIFICATION_USERS.split(',').map(u => u.trim())
            : ['562278615', '7639343315', '396182332', '5288412453'];

        const results = {
            success: 0,
            failed: 0,
            errors: []
        };

        for (const user of NOTIFICATION_USERS) {
            const chatId = user;
            const success = await telegramService.sendMessage(chatId, testMessage);

            if (success) {
                results.success++;
            } else {
                results.failed++;
                results.errors.push(username);
            }
        }

        res.json({
            success: true,
            message: `Test message sent to ${results.success} users`,
            data: results
        });
    } catch (error) {
        console.error('Send test message error:', error);
        res.status(500).json({
            success: false,
            message: 'Error sending test message',
            error: error.message
        });
    }
});

/**
 * Get bot info
 * GET /api/admin/telegram/bot-info
 */
router.get('/bot-info', auth.verifyToken, requireAdmin, async (req, res) => {
    try {
        const botInfo = await telegramService.getBotInfo();

        if (botInfo) {
            res.json({
                success: true,
                data: {
                    id: botInfo.id,
                    username: botInfo.username,
                    first_name: botInfo.first_name,
                    can_join_groups: botInfo.can_join_groups,
                    can_read_all_group_messages: botInfo.can_read_all_group_messages,
                    supports_inline_queries: botInfo.supports_inline_queries
                }
            });
        } else {
            res.status(500).json({
                success: false,
                message: 'Failed to get bot information'
            });
        }
    } catch (error) {
        console.error('Get bot info error:', error);
        res.status(500).json({
            success: false,
            message: 'Error getting bot information',
            error: error.message
        });
    }
});

module.exports = router;
