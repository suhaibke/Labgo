/**
 * OTP Service
 * Generates OTP codes locally and delivers them via OTPiq (WhatsApp SMS).
 * Unlike the previous provider (Arqam), OTPiq is send-only — it does not remember
 * or verify codes for us, so LabGo owns the code and verifies it locally.
 */

const crypto = require('crypto');

// Configuration
const OTPIQ_API_KEY = process.env.OTPIQ_API_KEY;
const OTPIQ_URL = 'https://otp.arqam.tech/api/sms/otp';

// OTP Settings
const OTP_EXPIRY_MINUTES = 10;
const MAX_ATTEMPTS = 3;
const RESEND_COOLDOWN_SECONDS = 60;
const MAX_DAILY_OTPS = 5;

// Holds codes for phones that don't have a User document yet (registration flow).
// Login/reset/phone-change flows persist the code onto User.otpCode/otpExpiry instead.
const pendingOtps = new Map(); // formattedPhone -> { code, expiresAt }

function cleanupExpiredPending() {
    const now = Date.now();
    for (const [phone, entry] of pendingOtps) {
        if (entry.expiresAt < now) pendingOtps.delete(phone);
    }
}

/**
 * Generate a random 6-digit OTP code
 */
function generateOtpCode() {
    return crypto.randomInt(100000, 999999).toString();
}

/**
 * Format phone number to international format
 */
function formatPhoneNumber(phone) {
    // Remove all non-digit characters
    let cleaned = phone.replace(/\D/g, '');

    // If doesn't start with country code, assume Iraq (+964)
    if (!cleaned.startsWith('964') && cleaned.startsWith('0')) {
        cleaned = '964' + cleaned.substring(1);
    } else if (!cleaned.startsWith('964')) {
        cleaned = '964' + cleaned;
    }

    return '+' + cleaned;
}

/**
 * Deliver a code via OTPiq (WhatsApp SMS)
 */
async function deliverViaOtpiq(formattedPhone, code) {
    const response = await fetch(OTPIQ_URL, {
        method: 'POST',
        headers: {
            'X-Api-Key': OTPIQ_API_KEY,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            phoneNumber: formattedPhone,
            otpCode: code,
        }),
    });

    const data = await response.json().catch(() => ({}));
    return { ok: response.ok, data };
}

/**
 * Generate an OTP code, deliver it via OTPiq, and cache it for phones without
 * a User document yet (registration). Callers with an existing User should also
 * persist the returned `code`/expiry onto `user.otpCode`/`user.otpExpiry`.
 * @param {string} phone - Phone number
 * @returns {Promise<Object>} { success, code, messageId, message }
 */
async function sendOtp(phone) {
    try {
        const formattedPhone = formatPhoneNumber(phone);
        const code = generateOtpCode();

        const { ok, data } = await deliverViaOtpiq(formattedPhone, code);

        if (!ok) {
            console.error('OTPiq send failed:', data);
            return {
                success: false,
                message: data.message || 'Failed to send OTP',
            };
        }

        cleanupExpiredPending();
        pendingOtps.set(formattedPhone, {
            code,
            expiresAt: Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000,
        });

        return {
            success: true,
            code,
            messageId: data.messageId || data.id || `otpiq_${Date.now()}`,
            message: 'OTP sent successfully',
        };
    } catch (error) {
        console.error('OTP Send Error:', error);
        return {
            success: false,
            message: 'Failed to send OTP. Please try again.',
        };
    }
}

/**
 * Send Password Reset OTP to phone number.
 * OTPiq has a single verification-code endpoint, so this reuses sendOtp.
 * @param {string} phone - Phone number
 * @returns {Promise<Object>} { success, code, messageId, message }
 */
async function sendPasswordResetOtp(phone) {
    return sendOtp(phone);
}

/**
 * Verify a submitted OTP code locally.
 * Checks the caller-supplied stored code/expiry first (User.otpCode/otpExpiry,
 * used for login/reset/phone-change), falling back to the pending-registration
 * cache keyed by phone (used when no User document exists yet).
 * @param {Object} params
 * @param {string} [params.phone] - Phone number (used for the pending-registration fallback)
 * @param {string|null} [params.storedCode] - Code stored on the User document, if any
 * @param {Date|string|null} [params.storedExpiry] - Expiry stored on the User document, if any
 * @param {string} params.code - Code submitted by the user
 * @returns {Object} { success, message }
 */
function verifyOtpLocal({ phone, storedCode, storedExpiry, code }) {
    let expectedCode = storedCode || null;
    let expiresAt = storedExpiry ? new Date(storedExpiry).getTime() : null;

    const formattedPhone = phone ? formatPhoneNumber(phone) : null;

    if (!expectedCode && formattedPhone) {
        cleanupExpiredPending();
        const pending = pendingOtps.get(formattedPhone);
        if (pending) {
            expectedCode = pending.code;
            expiresAt = pending.expiresAt;
        }
    }

    if (!expectedCode || !expiresAt) {
        return { success: false, message: 'No OTP was requested for this number' };
    }

    if (Date.now() > expiresAt) {
        return { success: false, message: 'OTP has expired' };
    }

    if (String(expectedCode) !== String(code)) {
        return { success: false, message: 'Invalid OTP code' };
    }

    if (formattedPhone) pendingOtps.delete(formattedPhone);
    return { success: true, message: 'OTP verified successfully' };
}

/**
 * Check if OTP has expired
 * @param {Date} expiry - OTP expiry date
 * @returns {boolean}
 */
function isOtpExpired(expiry) {
    if (!expiry) return true;
    return new Date() > new Date(expiry);
}

/**
 * Check if user can resend OTP (cooldown period)
 * @param {Date} lastSentAt - Last OTP send time
 * @returns {boolean}
 */
function canResendOtp(lastSentAt) {
    if (!lastSentAt) return true;
    const cooldownEnd = new Date(lastSentAt.getTime() + RESEND_COOLDOWN_SECONDS * 1000);
    return new Date() > cooldownEnd;
}

/**
 * Get remaining cooldown time in seconds
 * @param {Date} lastSentAt - Last OTP send time
 * @returns {number}
 */
function getResendCooldown(lastSentAt) {
    if (!lastSentAt) return 0;
    const cooldownEnd = new Date(lastSentAt.getTime() + RESEND_COOLDOWN_SECONDS * 1000);
    const remaining = Math.ceil((cooldownEnd - new Date()) / 1000);
    return Math.max(0, remaining);
}

module.exports = {
    generateOtpCode,
    formatPhoneNumber,
    sendOtp,
    sendPasswordResetOtp,
    verifyOtpLocal,
    isOtpExpired,
    canResendOtp,
    getResendCooldown,
    OTP_EXPIRY_MINUTES,
    MAX_ATTEMPTS,
    RESEND_COOLDOWN_SECONDS,
    MAX_DAILY_OTPS,
};
