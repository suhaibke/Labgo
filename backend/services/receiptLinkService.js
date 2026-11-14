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

// Short result link for messages (WhatsApp / SMS): /r/<8 characters>.
// The code is random and stored on the order; letters that look alike are left out.
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
const CODE_RE = /^[A-HJ-NP-Za-km-z2-9]{8}$/;
function newCode() {
    const bytes = crypto.randomBytes(8);
    let out = '';
    for (let i = 0; i < 8; i++) out += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
    return out;
}
function shortLink(baseUrl, code) {
    return `${String(baseUrl || '').replace(/\/+$/, '')}/r/${code}`;
}

module.exports = { receiptCode, key, checkKey, resultLink, newCode, shortLink, CODE_RE };
