// Samples sent between labs that are both on LabGo: directory of labs, the
// price from the receiving lab's B2B prices, and the receiving side's view.
const mongoose = require('mongoose');
const Lab = require('../models/Lab');
const { notifyLab } = require('./labNotify');

function escapeRegex(s) {
    return String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Registered, active labs other than this one (for "send to").
async function directory(selfLabId, q = '') {
    const query = { _id: { $ne: selfLabId }, status: 'Active' };
    const text = String(q || '').trim().slice(0, 60);
    if (text) query.$or = [{ name: new RegExp(escapeRegex(text), 'i') }, { nameAr: new RegExp(escapeRegex(text), 'i') }, { city: new RegExp(escapeRegex(text), 'i') }];
    const labs = await Lab.find(query).select('name city phone address averageRating').sort({ averageRating: -1, name: 1 }).limit(30).lean();
    return labs.map((l) => ({ id: String(l._id), name: l.name, city: l.city || '', phone: l.phone || '', address: l.address || '', rating: l.averageRating || 0 }));
}

function norm(s) {
    return String(s || '').trim().toLowerCase();
}

// Finds the receiving lab's own test for a test name (name, Arabic name or code).
function matchTest(lab, name) {
    const n = norm(name);
    return (lab.tests || []).find((t) => t.isActive !== false && (norm(t.name) === n || norm(t.nameAr) === n || norm(t.code) === n)) || null;
}

// Price the receiving lab charges other labs: its B2B price, else its normal price.
function quote(lab, testNames) {
    const lines = [];
    const missing = [];
    for (const name of testNames) {
        const t = matchTest(lab, name);
        if (!t) { missing.push(name); continue; }
        lines.push({ name, matched: t.name, price: t.priceB2B > 0 ? t.priceB2B : (t.price || 0) });
    }
    return { total: lines.reduce((s, l) => s + l.price, 0), lines, missing };
}

function testNamesOf(fields) {
    const fromTests = (fields.tests || []).map((t) => t.testName).filter(Boolean);
    if (fromTests.length) return fromTests;
    return String(fields.testsDescription || '').split(/[,،\n]/).map((s) => s.trim()).filter(Boolean);
}

/**
 * Before creating a transfer: when toLabId names a registered lab, use its name
 * and contact details unless typed, and remember it. Returns the lab or null.
 */
async function resolveTargetLab(body, selfLab) {
    const id = String(body?.toLabId || '');
    if (!mongoose.Types.ObjectId.isValid(id) || id === String(selfLab._id)) return null;
    const lab = await Lab.findOne({ _id: id, status: 'Active' }).select('name phone address city tests');
    if (!lab) return null;
    if (!String(body.labName || '').trim()) body.labName = lab.name;
    if (!body.phone) body.phone = lab.phone;
    if (!body.address) body.address = [lab.address, lab.city].filter(Boolean).join(' - ');
    return lab;
}

/** Sets toLabId and the price (typed price wins; else the B2B quote). */
function applyTargetAndPrice(fields, body, targetLab) {
    const typed = body?.price;
    const n = typed === null || typed === undefined || String(typed).trim() === '' ? null : Math.round(Number(String(typed).replace(/[^\d.]/g, '')));
    if (targetLab) fields.toLabId = targetLab._id;
    if (Number.isFinite(n) && n >= 0) {
        fields.price = n;
        fields.priceSource = 'manual';
    } else if (targetLab) {
        fields.price = quote(targetLab, testNamesOf(fields)).total;
        fields.priceSource = 'b2b';
    }
    return fields;
}

async function notifySent(transfer, fromLab) {
    if (!transfer.toLabId) return;
    await notifyLab(transfer.toLabId, {
        title: 'عينة جديدة في الطريق إليك',
        body: `${fromLab.name} أرسل عينة ${transfer.sampleCode} (${transfer.patientName})`,
        data: { type: 'transfer_incoming', transferId: String(transfer._id), sampleCode: transfer.sampleCode },
    });
}

// "3.5 - 7.2" / "3.5–7.2" -> { min: 3.5, max: 7.2 }; anything else stays text only.
function parseRange(text) {
    const m = /^\s*(-?\d+(?:\.\d+)?)\s*[-–—~]\s*(-?\d+(?:\.\d+)?)\s*$/.exec(String(text || ''));
    return m ? { min: Number(m[1]), max: Number(m[2]) } : { min: null, max: null };
}

/**
 * Saves the results of a sample sent to a lab that is not on LabGo — typed by
 * the sending lab, or entered by the receiving lab on the QR page.
 * rows: [{ testName, value, unit, range }]. Completes the transfer, and an
 * order it belongs to gets the values as a draft to review.
 */
async function saveExternalResults(t, rows, { source, userId = null, fileUrl = null } = {}) {
    const { classify } = require('../helpers/result-ranges');
    const clip = (v, n) => String(v ?? '').trim().slice(0, n);
    const values = (rows || [])
        .map((r) => {
            const range = clip(r.range, 80);
            const { min, max } = parseRange(range);
            const value = clip(r.value, 200);
            return { testName: clip(r.testName, 120), value, unit: clip(r.unit, 40), min, max, normalText: range, flag: classify(value, min, max) };
        })
        .filter((v) => v.testName && v.value);
    if (!values.length && !fileUrl) return false;
    if (!t.receiverResults) t.receiverResults = {};
    if (values.length) t.receiverResults.values = values;
    t.receiverResults.entryStatus = 'approved';
    t.receiverResults.enteredAt = new Date();
    t.receiverResults.approvedAt = new Date();
    if (userId) t.receiverResults.approvedBy = userId;
    if (fileUrl) t.resultFileUrl = fileUrl;
    t.status = 'completed';
    t.completedAt = new Date();
    t.resultSource = source;
    await t.save();
    // Typed values go to the order as a draft to review; a file alone waits for the lab.
    if (values.length) await require('../routes/lab/transfers-in').copyToSenderOrder(t);
    // The other lab answered through the QR page: the sending lab is told.
    if (source === 'external_link') {
        const from = t.externalUpload?.uploaderName || t.externalLab?.name || '';
        await notifyLab(t.labId, {
            title: 'وصلت نتيجة العينة المرسلة',
            body: `${from ? `${from} أرسل` : 'وصلت'} نتيجة ${t.trackingCode || t.sampleCode} (${t.patientName})${values.length ? '' : ' — ملف مرفق'}`,
            data: { type: 'transfer_result', transferId: String(t._id), sampleCode: t.trackingCode || t.sampleCode, orderId: t.orderId ? String(t.orderId) : null },
        });
    }
    return true;
}

/**
 * Results typed on the sending lab's own order also finish the samples it sent
 * out: a transfer whose tests all have a value on the order becomes completed
 * (its tracking timeline moves on). Never throws.
 */
async function syncFromOrder(order, userId = null) {
    try {
        const ExternalTransfer = require('../models/ExternalTransfer');
        const open = await ExternalTransfer.find({ orderId: order._id, status: 'sent' });
        if (!open.length) return 0;
        const byName = new Map((order.results?.values || []).filter((v) => String(v.value || '').trim()).map((v) => [v.testName, v]));
        let done = 0;
        for (const t of open) {
            const names = (t.tests || []).map((x) => x.testName).filter(Boolean);
            if (!names.length || !names.every((n) => byName.has(n))) continue;
            if (!t.receiverResults) t.receiverResults = {};
            t.receiverResults.values = names.map((n) => {
                const v = byName.get(n);
                return { testName: n, value: v.value, unit: v.unit || '', min: v.min ?? null, max: v.max ?? null, normalText: v.normalText || '', flag: v.flag || '' };
            });
            t.receiverResults.entryStatus = 'approved';
            t.receiverResults.approvedAt = new Date();
            if (userId) t.receiverResults.approvedBy = userId;
            t.status = 'completed';
            t.completedAt = new Date();
            t.resultSource = 'lab';
            await t.save();
            done += 1;
        }
        return done;
    } catch (error) {
        console.warn('Transfer sync from order failed:', error.message);
        return 0;
    }
}

module.exports = { syncFromOrder, directory, quote, matchTest, testNamesOf, resolveTargetLab, applyTargetAndPrice, notifySent, saveExternalResults, parseRange };
