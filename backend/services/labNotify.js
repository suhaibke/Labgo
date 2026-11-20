// In-app notifications between labs (sample sent, received, result ready).
// Every person who works at the lab gets one: the owner and active staff.
const Lab = require('../models/Lab');
const User = require('../models/User');
const Notification = require('../models/Notification');

async function labUserIds(labId) {
    const [lab, staff] = await Promise.all([
        Lab.findById(labId).select('ownerId'),
        User.find({ 'labStaff.labId': labId, 'labStaff.active': { $ne: false }, role: 'lab' }).select('_id'),
    ]);
    const ids = new Set(staff.map((u) => String(u._id)));
    if (lab?.ownerId) ids.add(String(lab.ownerId));
    return [...ids];
}

/**
 * @param labId  the lab to notify
 * @param n      { title, body, data } — data.type e.g. 'transfer_sent'
 * Never throws: a notification failure must not break the action itself.
 */
// Push never blocks or breaks the action that triggered it.
function pushAll(userIds, title, body, data) {
    let fcm;
    try {
        fcm = require('./fcmService');
    } catch (error) {
        return; // no Firebase key on this server (local dev)
    }
    for (const id of userIds) {
        fcm.pushToUser(id, title, body, data).catch((error) => console.warn('Lab push failed:', error.message));
    }
}

async function notifyLab(labId, { title, body, data = {} }) {
    try {
        if (!labId) return 0;
        // Live sync: open web dashboards of this lab refresh what the event is about
        // (a sample from another lab, results returned, admin decisions…).
        try {
            const t = String(data.type || '');
            const kind = /result/.test(t) ? 'results' : /transfer|sample/.test(t) ? 'transfers' : /maint/.test(t) ? 'maintenance'
                : /waste/.test(t) ? 'waste' : /market|auction|order|support|ticket|listing/.test(t) ? 'store' : 'notification';
            const path = { results: '/transfers/incoming', transfers: '/transfers/incoming', maintenance: '/api/maintenance', waste: '/waste', store: '/api/market' }[kind] || '/api/notifications';
            require('./labLive').publish(labId, { kind, path, method: 'NOTIFY', source: 'server', by: '', client: '', type: t });
        } catch (_) { /* live sync is best effort */ }
        const ids = await labUserIds(labId);
        if (!ids.length) return 0;
        await Notification.insertMany(ids.map((userId) => ({ userId, title, body, data: { audience: 'lab', ...data } })));
        // Also as a push to the phones of the lab's people (when the lab app registered them).
        pushAll(ids, title, body, { audience: 'lab', ...data });
        return ids.length;
    } catch (error) {
        console.error('Lab notification error:', error);
        return 0;
    }
}

module.exports = { notifyLab, labUserIds };
