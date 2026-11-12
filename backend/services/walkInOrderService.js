// Builds a lab-reception ("walk-in") order: the patient is at the lab, the
// sample is taken there, so the order starts at 'at_lab' with no nurse and
// no platform commission.
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const Order = require('../models/Order');
const Package = require('../models/Package');
const Counter = require('../models/Counter');
const { getPhoneLoginCandidates, findByPhone } = require('../helpers/phone');

class WalkInError extends Error {
    constructor(message, status = 400) {
        super(message);
        this.status = status;
    }
}

const SAMPLE_TYPES = ['', 'blood', 'urine', 'stool', 'swab', 'csf'];
const AGE_UNITS = { Y: 'Y', M: 'M', D: 'D' };

function birthDateFromAge(value, unit, now = new Date()) {
    const n = Number(value);
    if (!Number.isFinite(n) || n < 0 || n > 130) return null;
    const d = new Date(now);
    if (unit === 'M') d.setMonth(d.getMonth() - Math.round(n));
    else if (unit === 'D') d.setDate(d.getDate() - Math.round(n));
    else d.setFullYear(d.getFullYear() - Math.round(n));
    return d;
}

function cleanPhone(phone) {
    const raw = String(phone || '').trim();
    const digits = raw.replace(/\D/g, '');
    if (digits.length < 10) return null;
    // Store in the local format the patient app uses (07xxxxxxxxx).
    const candidates = getPhoneLoginCandidates(raw);
    return { stored: candidates.find((c) => /^0\d{10}$/.test(c)) || digits, candidates };
}

// Splits a package price across its tests in proportion to their own prices
// (same as the patient app cart), so the order total stays a plain sum.
function packageLines(pkg, tests) {
    const individualTotal = tests.reduce((sum, t) => sum + (t.price || 0), 0) || 1;
    let distributed = 0;
    return tests.map((test, index) => {
        const isLast = index === tests.length - 1;
        const share = isLast ? pkg.price - distributed : Math.round(((test.price || 0) / individualTotal) * pkg.price);
        distributed += share;
        return {
            testId: test._id,
            testName: test.name,
            testCode: test.code,
            category: test.category || 'General',
            price: Math.max(0, share),
            originalPrice: test.price,
        };
    });
}

async function resolveTests(lab, testIds = [], packageIds = []) {
    const labTests = lab.tests || [];
    const byId = new Map(labTests.map((t) => [String(t._id), t]));
    const lines = [];
    const seen = new Set();

    if (packageIds.length) {
        const packages = await Package.find({ _id: { $in: packageIds }, labId: lab._id, isActive: true }).lean();
        for (const pkg of packages) {
            const tests = (pkg.testIds || []).map((id) => byId.get(String(id))).filter(Boolean);
            if (!tests.length) continue;
            for (const line of packageLines(pkg, tests)) {
                seen.add(String(line.testId));
                lines.push(line);
            }
        }
    }
    for (const id of testIds) {
        const t = byId.get(String(id));
        if (!t || seen.has(String(t._id))) continue;
        seen.add(String(t._id));
        lines.push({ testId: t._id, testName: t.name, testCode: t.code, category: t.category || 'General', price: t.price || 0 });
    }
    return lines;
}

// Older patients may not have an ID number yet; give them one without
// re-validating the whole account.
async function ensurePatientNo(user) {
    if (user.patientNo !== undefined && user.patientNo !== null) return user.patientNo;
    const no = await Counter.next('patientNo', 100000);
    await User.updateOne({ _id: user._id, patientNo: { $exists: false } }, { $set: { patientNo: no } });
    user.patientNo = no;
    return no;
}

// Finds the account for this phone, or creates a placeholder the patient can
// claim later by registering with the same phone.
async function resolvePatient(lab, { name, phone, gender, birthDate }) {
    const p = cleanPhone(phone);
    if (!p) throw new WalkInError('A valid phone number is required');
    let user = await findByPhone(User, p.candidates);
    if (user && user.role !== 'patient') {
        throw new WalkInError('This phone number belongs to a staff account');
    }
    if (!user) {
        const password = await bcrypt.hash(crypto.randomBytes(24).toString('hex'), 10);
        user = new User({
            name, phone: p.stored, gender: gender || null, birthDate, password, role: 'patient',
            labPlaceholder: true, createdByLabId: lab._id,
        });
        await user.save();
        return { user, beneficiary: null };
    }
    const sameName = String(user.name || '').trim().toLowerCase() === String(name).trim().toLowerCase();
    if (user.labPlaceholder && sameName) {
        // Keep the placeholder's details fresh.
        if (gender) user.gender = gender;
        if (birthDate) user.birthDate = birthDate;
        await user.save();
        return { user, beneficiary: null };
    }
    if (sameName) return { user, beneficiary: null };
    // Someone else using this phone (e.g. a child on a parent's number).
    return {
        user,
        beneficiary: { isForOtherPerson: true, name, phone: p.stored, gender: gender || undefined, birthDate, relationship: 'other' },
    };
}

async function createWalkInOrder(lab, staffUserId, body = {}) {
    const name = String(body.name || '').trim().slice(0, 120);
    if (!name) throw new WalkInError('Patient name is required');
    const gender = ['male', 'female'].includes(body.gender) ? body.gender : null;
    const birthDate = birthDateFromAge(body.age, AGE_UNITS[body.ageUnit] || 'Y');

    const testIds = Array.isArray(body.testIds) ? body.testIds.map(String) : [];
    const packageIds = Array.isArray(body.packageIds) ? body.packageIds.map(String) : [];
    const tests = await resolveTests(lab, testIds, packageIds);
    if (!tests.length) throw new WalkInError('Choose at least one test');

    const subtotal = tests.reduce((sum, t) => sum + t.price, 0);
    const discount = Math.min(subtotal, Math.max(0, Math.round(Number(body.discount) || 0)));
    const total = subtotal - discount;
    const paid = body.payLater !== true;
    const now = new Date();

    const { user, beneficiary } = await resolvePatient(lab, { name, phone: body.phone, gender, birthDate });

    const order = new Order({
        patientId: user._id,
        beneficiary: beneficiary || { isForOtherPerson: false },
        labId: lab._id,
        tests,
        qrCode: Order.generateQRCode(),
        location: {
            address: [lab.address, lab.city].filter(Boolean).join(' - ') || lab.name,
            coordinates: {
                latitude: lab.coordinates?.latitude ?? 0,
                longitude: lab.coordinates?.longitude ?? 0,
            },
        },
        orderType: 'walk_in',
        walkIn: {
            doctor: String(body.doctor || '').trim().slice(0, 120),
            company: String(body.company || '').trim().slice(0, 120),
            sampleType: SAMPLE_TYPES.includes(body.sampleType) ? body.sampleType : '',
            createdBy: staffUserId,
        },
        urgency: body.urgency === 'urgent' ? 'urgent' : 'routine',
        status: 'at_lab',
        orderCategory: 'test',
        payment: { status: paid ? 'paid' : 'pending', method: 'cash', amount: total, currency: 'IQD', paidAt: paid ? now : undefined, collectedBy: paid ? staffUserId : undefined },
        paymentCollected: { collected: paid, collectedAt: paid ? now : undefined, collectedBy: paid ? staffUserId : undefined },
        pricing: { subtotal, discount, total },
        notes: { labNotes: String(body.notes || '').trim().slice(0, 1000) },
        financials: { labCommissionRate: 0, labAmount: total },
    });
    await order.save();
    // The ID belongs to the account holder; someone else using their phone has none.
    order.$locals.patientNo = beneficiary ? null : await ensurePatientNo(user);
    return order;
}

// Autofill for the reception form: only patients this lab already knows.
// Accepts a phone number or a patient ID number (6-8 digits).
async function lookupPatient(lab, query) {
    const raw = String(query || '').trim();
    const digits = raw.replace(/\D/g, '');
    let user = null;
    if (digits.length >= 6 && digits.length <= 8 && digits === raw.replace(/^#/, '')) {
        user = await User.findOne({ patientNo: Number(digits), role: 'patient' });
    } else {
        const p = cleanPhone(raw);
        if (!p) return null;
        user = await findByPhone(User, p.candidates, { role: 'patient' });
    }
    if (!user) return null;
    const known = String(user.createdByLabId || '') === String(lab._id)
        || await Order.exists({ labId: lab._id, patientId: user._id });
    if (!known) return null;
    return { name: user.name, phone: user.phone || '', patientNo: user.patientNo ?? null, gender: user.gender || null, birthDate: user.birthDate || null };
}

module.exports = { createWalkInOrder, lookupPatient, birthDateFromAge, packageLines, WalkInError };
