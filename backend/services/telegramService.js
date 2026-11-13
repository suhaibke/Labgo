const axios = require('axios');

// Telegram Bot Configuration
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '';

// List of chat IDs or usernames to notify when a new order is created
// Use chat IDs for reliability (usernames can change)
// Chat IDs are numeric, usernames start with @
const NOTIFICATION_USERS = process.env.TELEGRAM_NOTIFICATION_USERS
    ? process.env.TELEGRAM_NOTIFICATION_USERS.split(',').map(u => u.trim())
    : ['562278615', '7639343315', '396182332', '5288412453']; // Admin notification recipients

class TelegramService {
    constructor() {
        this.apiBaseUrl = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}`;
    }

    /**
     * Send a message to a specific Telegram chat
     * @param {string} chatId - The Telegram chat ID or username
     * @param {string} message - The message to send
     * @param {object} options - Additional options (parse_mode, disable_notification, etc.)
     * @returns {Promise<boolean>} - Success status
     */
    async sendMessage(chatId, message, options = {}) {
        if (!TELEGRAM_BOT_TOKEN) return false; // not configured on this server
        try {
            const response = await axios.post(`${this.apiBaseUrl}/sendMessage`, {
                chat_id: chatId,
                text: message,
                parse_mode: 'HTML',
                disable_web_page_preview: true,
                ...options
            });

            if (response.data.ok) {
                console.log(`Telegram message sent successfully to ${chatId}`);
                return true;
            } else {
                console.error(`Telegram API error: ${response.data.description}`);
                return false;
            }
        } catch (error) {
            console.error('Error sending Telegram message:', error.message);
            return false;
        }
    }

    /**
     * Send a new order notification to all configured users
     * @param {object} order - The order object with populated fields
     * @returns {Promise<object>} - Results summary
     */
    async sendNewOrderNotification(order) {
        const results = {
            success: 0,
            failed: 0,
            errors: []
        };

        // Format the order message
        const message = this.formatOrderMessage(order);

        // Send to each configured user (chat ID or username)
        for (const user of NOTIFICATION_USERS) {
            // If it's a username (starts with @), use as-is
            // If it's a number (chat ID), use as-is
            const chatId = user;
            const success = await this.sendMessage(chatId, message);

            if (success) {
                results.success++;
            } else {
                results.failed++;
                results.errors.push(username);
            }
        }

        // Log summary
        console.log(`Telegram notification summary: ${results.success} sent, ${results.failed} failed`);
        if (results.errors.length > 0) {
            console.error('Failed to send to:', results.errors);
        }

        return results;
    }

    /**
     * Format an order into a readable Telegram message
     * @param {object} order - The order object
     * @returns {string} - Formatted HTML message
     */
    formatOrderMessage(order) {
        const patientName = order.patientId?.name || 'غير متوفر';
        const patientPhone = order.patientId?.phone || 'غير متوفر';
        const patientEmail = order.patientId?.email || 'غير متوفر';

        const labName = order.labId?.name || 'غير متوفر';
        const labAddress = order.labId?.address || 'غير متوفر';
        const labPhone = order.labId?.phone || 'غير متوفر';

        const address = order.location?.address || 'غير متوفر';
        const orderType = order.orderType || 'home_collection';

        const totalAmount = order.pricing?.total || 0;
        const currency = order.payment?.currency || 'IQD';

        // Format tests list
        const testsList = order.tests?.map(test => {
            return `• <b>${test.testName}</b> - ${this.formatCurrency(test.price, currency)}`;
        }).join('\n') || 'لا توجد تحاليل';

        // Format date
        const orderDate = new Date(order.createdAt).toLocaleString('ar-IQ', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });

        const typeText = orderType === 'home_collection' ? 'جمع من المنزل' :
            orderType === 'lab_visit' ? 'زيارة المختبر' : orderType;

        // Beneficiary info (if order is for another person)
        let beneficiarySection = '';
        if (order.beneficiary?.isForOtherPerson) {
            const beneficiaryName = order.beneficiary.name || 'غير متوفر';
            const beneficiaryPhone = order.beneficiary.phone || 'غير متوفر';
            const beneficiaryGender = order.beneficiary.gender === 'male' ? 'ذكر' :
                order.beneficiary.gender === 'female' ? 'أنثى' : '';
            const relationshipMap = {
                'spouse': 'زوج/زوجة',
                'child': 'طفل',
                'parent': 'والد/والدة',
                'sibling': 'أخ/أخت',
                'other': 'آخر'
            };
            const relationship = relationshipMap[order.beneficiary.relationship] || order.beneficiary.relationship || '';

            beneficiarySection = `
👥 <b>الطلب لشخص آخر</b>
👤 اسم المستفيد: ${beneficiaryName}
📞 هاتف المستفيد: ${beneficiaryPhone}${beneficiaryGender ? `
⚧ الجنس: ${beneficiaryGender}` : ''}${relationship ? `
👨‍👩‍👧 صلة القرابة: ${relationship}` : ''}
`;
        }

        return `🆕 <b>طلب جديد مستلم</b>

📋 <b>تفاصيل الطلب</b>
🔖 رقم الطلب: <code>${order._id}</code>
📅 التاريخ: ${orderDate}
🏠 النوع: ${typeText}

👤 <b>معلومات صاحب الحساب</b>
👤 الاسم: ${patientName}
📞 الهاتف: ${patientPhone}
📧 البريد الإلكتروني: ${patientEmail}
${beneficiarySection}
🏥 <b>معلومات المختبر</b>
🏢 الاسم: ${labName}
📍 العنوان: ${labAddress}
📞 الهاتف: ${labPhone}

📍 <b>موقع الجمع</b>
🗺️ العنوان: ${address}

🧪 <b>التحاليل المطلوبة</b>
${testsList}

💰 <b>التسعير</b>
المجموع: ${this.formatCurrency(totalAmount, currency)}

⏳ الحالة: <b>معلق</b>

─────────────────
يرجى مراجعة لوحة التحكم للمزيد من التفاصيل.`;
    }

    /**
     * Format currency amount
     * @param {number} amount - The amount to format
     * @param {string} currency - The currency code
     * @returns {string} - Formatted currency string
     */
    formatCurrency(amount, currency = 'IQD') {
        if (currency === 'IQD') {
            return new Intl.NumberFormat('en-IQ', {
                style: 'currency',
                currency: 'IQD',
                minimumFractionDigits: 0,
                maximumFractionDigits: 0
            }).format(amount);
        }
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: currency
        }).format(amount);
    }

    /**
     * Send order status update notification
     * @param {object} order - The order object
     * @param {string} oldStatus - Previous status
     * @param {string} newStatus - New status
     * @returns {Promise<object>} - Results summary
     */
    async sendOrderStatusUpdate(order, oldStatus, newStatus) {
        const results = {
            success: 0,
            failed: 0,
            errors: []
        };

        const statusEmojis = {
            'pending': '⏳',
            'confirmed': '✅',
            'nurse_assigned': '👨‍⚕️',
            'sample_collected': '🧪',
            'at_lab': '🏥',
            'completed': '✅',
            'cancelled': '❌'
        };

        const statusTexts = {
            'pending': 'معلق',
            'confirmed': 'مؤكد',
            'nurse_assigned': 'تقني المختبر في الطريق',
            'sample_collected': 'تم جمع العينة',
            'at_lab': 'العينة في المختبر',
            'completed': 'مكتمل',
            'cancelled': 'ملغي'
        };

        const oldStatusText = statusTexts[oldStatus] || oldStatus;
        const newStatusText = statusTexts[newStatus] || newStatus;

        const message = `🔄 <b>تحديث حالة الطلب</b>

🔖 رقم الطلب: <code>${order._id}</code>
${statusEmojis[oldStatus] || '📋'} ${oldStatusText}
     ↓
${statusEmojis[newStatus] || '📋'} ${newStatusText}

المريض: ${order.patientId?.name || 'غير متوفر'}
المختبر: ${order.labId?.name || 'غير متوفر'}

تم التحديث: ${new Date().toLocaleString('ar-IQ')}`;

        for (const user of NOTIFICATION_USERS) {
            const chatId = user;
            const success = await this.sendMessage(chatId, message);

            if (success) {
                results.success++;
            } else {
                results.failed++;
                results.errors.push(username);
            }
        }

        return results;
    }

    /**
     * Send a new shop order notification to all configured users
     * @param {object} order - The shop order object
     * @returns {Promise<object>} - Results summary
     */
    async sendNewShopOrderNotification(order) {
        const results = {
            success: 0,
            failed: 0,
            errors: []
        };

        // Format the shop order message
        const message = this.formatShopOrderMessage(order);

        // Send to each configured user (chat ID or username)
        for (const user of NOTIFICATION_USERS) {
            const chatId = user;
            const success = await this.sendMessage(chatId, message);

            if (success) {
                results.success++;
            } else {
                results.failed++;
                results.errors.push(user);
            }
        }

        // Log summary
        console.log(`Telegram shop order notification summary: ${results.success} sent, ${results.failed} failed`);
        if (results.errors.length > 0) {
            console.error('Failed to send to:', results.errors);
        }

        return results;
    }

    /**
     * Format a shop order into a readable Telegram message
     * @param {object} order - The shop order object
     * @returns {string} - Formatted HTML message
     */
    formatShopOrderMessage(order) {
        const customerName = order.customer?.name || 'غير متوفر';
        const customerPhone = order.customer?.phone || 'غير متوفر';

        const deliveryAddress = order.deliveryAddress?.address || 'غير متوفر';
        const deliveryCity = order.deliveryAddress?.city || '';
        const deliveryNotes = order.deliveryAddress?.notes || '';

        const totalAmount = order.pricing?.total || 0;
        const subtotal = order.pricing?.subtotal || 0;
        const deliveryFee = order.pricing?.deliveryFee || 0;
        const currency = order.pricing?.currency || 'IQD';

        // Format items list
        const itemsList = order.items?.map(item => {
            const itemName = item.name?.ar || item.name?.en || item.name || 'منتج';
            return `• <b>${itemName}</b> × ${item.quantity} - ${this.formatCurrency(item.subtotal, currency)}`;
        }).join('\n') || 'لا توجد منتجات';

        // Format date
        const orderDate = new Date(order.createdAt).toLocaleString('ar-IQ', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });

        const paymentMethod = order.payment?.method === 'cash_on_delivery' ? 'الدفع عند الاستلام' :
            order.payment?.method || 'غير محدد';

        return `🛒 <b>طلب جديد من المتجر</b>

📋 <b>تفاصيل الطلب</b>
🔖 رقم الطلب: <code>${order.orderNumber || order._id}</code>
📅 التاريخ: ${orderDate}

👤 <b>معلومات العميل</b>
👤 الاسم: ${customerName}
📞 الهاتف: ${customerPhone}

📍 <b>عنوان التوصيل</b>
🗺️ العنوان: ${deliveryAddress}${deliveryCity ? `
🏙️ المدينة: ${deliveryCity}` : ''}${deliveryNotes ? `
📝 ملاحظات: ${deliveryNotes}` : ''}

📦 <b>المنتجات المطلوبة</b>
${itemsList}

💰 <b>التسعير</b>
المجموع الفرعي: ${this.formatCurrency(subtotal, currency)}${deliveryFee > 0 ? `
رسوم التوصيل: ${this.formatCurrency(deliveryFee, currency)}` : ''}
<b>الإجمالي: ${this.formatCurrency(totalAmount, currency)}</b>

💳 طريقة الدفع: ${paymentMethod}
⏳ الحالة: <b>معلق</b>

─────────────────
يرجى مراجعة لوحة التحكم للمزيد من التفاصيل.`;
    }

    /**
     * Test the Telegram bot connection
     * @returns {Promise<boolean>} - Connection status
     */
    async testConnection() {
        try {
            const response = await axios.get(`${this.apiBaseUrl}/getMe`);
            return response.data.ok;
        } catch (error) {
            console.error('Telegram bot connection failed:', error.message);
            return false;
        }
    }

    /**
     * Get bot information
     * @returns {Promise<object|null>} - Bot info or null
     */
    async getBotInfo() {
        try {
            const response = await axios.get(`${this.apiBaseUrl}/getMe`);
            if (response.data.ok) {
                return response.data.result;
            }
            return null;
        } catch (error) {
            console.error('Error getting bot info:', error.message);
            return null;
        }
    }
}

// Create and export singleton instance
const telegramService = new TelegramService();

module.exports = telegramService;
