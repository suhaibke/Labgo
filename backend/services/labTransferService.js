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

module.exports = { directory, quote, matchTest, testNamesOf, resolveTargetLab, applyTargetAndPrice, notifySent };
