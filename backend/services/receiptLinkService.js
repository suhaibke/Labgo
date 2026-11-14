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

// Short result link for messages (WhatsApp / SMS): /r/V0001-k7Qm2x.
// The order number keeps the link readable; the six random characters after
// it stop anyone from opening other results by changing the number, and tell
// labs apart (every lab has its own V0001). Orders without a receipt number
// get eight random characters. Letters that look alike are left out.
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
const CODE_RE = /^(?:V\d{1,9}-[A-HJ-NP-Za-km-z2-9]{6}|[A-HJ-NP-Za-km-z2-9]{8})$/;
function randomChars(n) {
    const bytes = crypto.randomBytes(n);
    let out = '';
    for (let i = 0; i < n; i++) out += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
    return out;
}
function newCode(order) {
    return order?.receiptNo ? `${receiptCode(order)}-${randomChars(6)}` : randomChars(8);
}
// What was typed in the address bar → the stored code (v0001-… and V0001-… are the same).
function normalizeCode(raw) {
    const s = String(raw || '').trim().replace(/^v(?=\d)/, 'V');
    return CODE_RE.test(s) ? s : null;
}
function shortLink(baseUrl, code) {
    return `${String(baseUrl || '').replace(/\/+$/, '')}/r/${code}`;
}

module.exports = { receiptCode, key, checkKey, resultLink, newCode, normalizeCode, shortLink, CODE_RE };
