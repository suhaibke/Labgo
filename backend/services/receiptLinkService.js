// Receipt numbers (V0001) and the QR link on the receipt: it opens the result
// once the lab approves it, and says "not ready yet" until then.
const crypto = require('crypto');
const { jwtSecret } = require('../config/secrets');

function receiptCode(order) {
    return order?.receiptNo ? `V${String(order.receiptNo).padStart(4, '0')}` : (order?.qrCode || '');
}

function key(orderId) {
    return crypto.createHmac('sha256', `receipt:${process.env.REPORT_SIGNING_SECRET || jwtSecret()}`).update(String(orderId)).digest('base64url').slice(0, 16);
}

function checkKey(orderId, k) {
    const a = Buffer.from(key(orderId));
    const b = Buffer.from(String(k || ''));
    return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function resultLink(baseUrl, orderId) {
    return `${String(baseUrl || '').replace(/\/+$/, '')}/r/o/${orderId}?k=${key(orderId)}`;
}

module.exports = { receiptCode, key, checkKey, resultLink };
