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
async function notifyLab(labId, { title, body, data = {} }) {
    try {
        if (!labId) return 0;
        const ids = await labUserIds(labId);
        if (!ids.length) return 0;
        await Notification.insertMany(ids.map((userId) => ({ userId, title, body, data: { audience: 'lab', ...data } })));
        return ids.length;
    } catch (error) {
        console.error('Lab notification error:', error);
        return 0;
    }
}

module.exports = { notifyLab, labUserIds };
