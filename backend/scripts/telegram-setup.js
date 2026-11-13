#!/usr/bin/env node

/**
 * Telegram Bot Setup Script
 *
 * This script helps set up the Telegram bot for notifications.
 * Instructions:
 * 1. Search for your bot (@labgo_bot) on Telegram
 * 2. Click "Start" or send /start to the bot
 * 3. Run this script to verify the setup
 */

const axios = require('axios');

const BOT_TOKEN = '8370600756:AAEbD3CvJaD4n2Mr-SLcF37SY9W4vA11uXY';
const API_URL = `https://api.telegram.org/bot${BOT_TOKEN}`;

console.log('🤖 LabGo Telegram Bot Setup\n');
console.log('Bot Username: @labgo_bot');
console.log('─────────────────────────────────────\n');

// Test bot connection
async function testConnection() {
    try {
        const response = await axios.get(`${API_URL}/getMe`);
        if (response.data.ok) {
            const bot = response.data.result;
            console.log('✅ Bot connected successfully!');
            console.log(`   Name: ${bot.first_name}`);
            console.log(`   Username: @${bot.username}`);
            console.log(`   ID: ${bot.id}`);
            return true;
        }
        return false;
    } catch (error) {
        console.error('❌ Failed to connect to bot:', error.message);
        return false;
    }
}

// Get bot updates (to see who started the bot)
async function getUpdates() {
    try {
        const response = await axios.get(`${API_URL}/getUpdates`);
        if (response.data.ok) {
            const updates = response.data.result;
            if (updates.length > 0) {
                console.log('\n📨 Recent updates (users who started the bot):');
                updates.forEach(update => {
                    if (update.message) {
                        const chat = update.message.chat;
                        console.log(`   - ${chat.first_name || 'User'} (@${chat.username || 'no username'})`);
                        console.log(`     Chat ID: ${chat.id}`);
                        console.log(`     Type: ${chat.type}`);
                    }
                });
            } else {
                console.log('\n⚠️  No updates yet.');
                console.log('   Please start the bot by:');
                console.log('   1. Open Telegram');
                console.log('   2. Search for @labgo_bot');
                console.log('   3. Click "Start" or send /start');
                console.log('   4. Run this script again');
            }
        }
    } catch (error) {
        console.error('❌ Error getting updates:', error.message);
    }
}

// Send test message
async function sendTestMessage(chatId) {
    try {
        const message = `✅ <b>تم إعداد بوت تيليجرام لنظام لاب جو بنجاح!</b>

سوف تستلم الآن إشعارات عن:
• الطلبات الجديدة
• تحديثات حالة الطلبات
• التحديثات المهمة

تم الإرسال: ${new Date().toLocaleString('ar-IQ')}`;

        const response = await axios.post(`${API_URL}/sendMessage`, {
            chat_id: chatId,
            text: message,
            parse_mode: 'HTML'
        });

        if (response.data.ok) {
            console.log('\n✅ Test message sent successfully!');
            console.log(`   Chat ID: ${chatId}`);
            console.log('\n📝 Add this to your .env file:');
            console.log(`   TELEGRAM_NOTIFICATION_USERS=${chatId}`);
            return true;
        }
        return false;
    } catch (error) {
        console.error('\n❌ Failed to send test message:', error.response?.data?.description || error.message);
        return false;
    }
}

// Main execution
(async () => {
    const isConnected = await testConnection();
    if (!isConnected) {
        process.exit(1);
    }

    await getUpdates();

    // If chat ID is provided as argument, send test message
    const chatId = process.argv[2];
    if (chatId) {
        await sendTestMessage(chatId);
    }

    console.log('\n─────────────────────────────────────');
    console.log('\n💡 Usage:');
    console.log('   node scripts/telegram-setup.js           - Check bot status');
    console.log('   node scripts/telegram-setup.js <chat_id>  - Send test message');
})();
