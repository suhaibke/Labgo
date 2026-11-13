// Data for the lab mobile app, in the shapes the app already uses
// (Patient, CatalogTest, LabPackage). Same auth and permissions as the
// dashboard: the app signs in with /api/auth/login and sends the token.
const express = require('express');
const Order = require('../../models/Order');
const Package = require('../../models/Package');
const Lab = require('../../models/Lab');
const ExternalTransfer = require('../../models/ExternalTransfer');
const { summary: financeSummary, labShare } = require('../../services/labFinanceService');
const { buildCommonFields, resolveOrderTests, ExternalTransferError } = require('../../services/externalTransferService');
const { cleanLicenseHolders } = require('../../helpers/license-holders');
const labTransfers = require('../../services/labTransferService');
const TEST_CATEGORIES = Lab.schema.path('tests').schema.path('category').enumValues;
const PACKAGE_CATEGORIES = Package.schema.path('category').enumValues;
const { decorateOrderWithPatientInfo } = require('../../helpers/order-patient-info');

const router = express.Router();
const patientFields = 'name phone gender birthDate patientNo';
const SAMPLE = { blood: 'Blood', urine: 'Urine', stool: 'Stool', swab: 'Swab', csf: 'CSF' };

function two(n) { return String(n).padStart(2, '0'); }

// "32Y", or months/days for babies (the app's age format).
function ageText(info) {
    if (info.birthDate) {
        const days = Math.floor((Date.now() - new Date(info.birthDate).getTime()) / 86400000);
        if (days >= 0 && days < 31) return `${days}D`;
        if (days >= 0 && days < 365) return `${Math.floor(days / 30)}M`;
    }
    return Number.isInteger(info.age) ? `${info.age}Y` : '—';
}

function appStatus(order) {
    if (order.status === 'completed') return 'Completed';
    if (order.orderType === 'walk_in' && order.payment?.status === 'pending') return 'Payment Pending';
    return 'Pending';
}

function toAppPatient(order) {
    const o = decorateOrderWithPatientInfo(order);
    const info = o.patientInfo || {};
    const created = new Date(o.createdAt);
    const results = {};
    for (const v of o.results?.values || []) if (v.value) results[v.testName] = v.value;
    const company = o.walkIn?.company || '';
    return {
        id: String(o._id),
        name: info.name || '',
        age: ageText(info),
        gender: info.gender === 'female' ? 'Female' : 'Male',
        phone: info.phone || '',
        tests: (o.tests || []).map((t) => t.testName),
        sample: SAMPLE[o.walkIn?.sampleType] || 'Blood',
        urgency: o.urgency === 'urgent' || o.urgency === 'emergency' ? 'Urgent' : 'Normal',
        notes: o.notes?.labNotes || '',
        status: appStatus(o),
        time: Number.isNaN(created.getTime()) ? '' : `${two(created.getHours())}:${two(created.getMinutes())}`,
        createdAt: o.createdAt,
        price: o.pricing?.total || 0,
        doctor: o.walkIn?.doctor || '',
        mode: company ? 'B2B' : 'B2C',
        company: company || null,
        results,
        resultStatus: o.results?.entryStatus || 'none',
        permanent: info.patientNo ? `#${info.patientNo}` : (o.qrCode || ''),
        orderCode: o.qrCode || '',
    };
}

function rangeRows(t) {
    return (t.ranges || []).map((r) => ({
        ageFrom: String(r.ageFrom ?? 0), ageTo: String(r.ageTo ?? 120), ageUnit: r.ageUnit || 'Y',
        gender: r.gender || 'Both', min: r.min === null || r.min === undefined ? '' : String(r.min),
        max: r.max === null || r.max === undefined ? '' : String(r.max),
    }));
}

// One entry per test name; orders made in the patient app may carry the
// Arabic name, so that name gets a hidden entry with the same ranges.
function toCatalog(tests) {
    const out = [];
    for (const t of tests || []) {
        const base = {
            id: String(t._id), name: t.name, price: t.price || 0, priceB2B: t.priceB2B > 0 ? t.priceB2B : (t.price || 0),
            category: t.category || 'General', units: t.unit || '', normalText: t.normalText || '', ranges: rangeRows(t),
        };
        out.push({ ...base, on: t.isActive !== false });
        if (t.nameAr && t.nameAr !== t.name) out.push({ ...base, name: t.nameAr, on: false, alias: true });
    }
    return out;
}

async function patientsFor(lab) {
    const orders = await Order.find({ labId: lab._id, status: { $in: ['at_lab', 'completed'] } })
        .populate('patientId', patientFields)
        .sort({ createdAt: -1 })
        .limit(200);
    return orders.map(toAppPatient);
}

router.get('/api/app/bootstrap', async (req, res) => {
    try {
        const lab = req.lab;
        const packages = await Package.find({ labId: lab._id }).lean();
        const nameById = new Map((lab.tests || []).map((t) => [String(t._id), t.name]));
        res.json({
            success: true,
            data: {
                user: { name: req.user.name || '', phone: req.user.phone || '', isOwner: Boolean(req.isLabOwner), permissions: req.labPermissions || [] },
                lab: { name: lab.name || '', phone: lab.phone || '', address: lab.address || '', city: lab.city || '', logo: lab.logo || '', licenseOwners: holdersToText(lab.licenseHolders) },
                catalog: toCatalog(lab.tests),
                packages: packages.map((p) => ({
                    id: String(p._id), code: '', name: p.nameAr || p.name, category: p.category || 'General', aliases: [p.name, p.nameAr].filter(Boolean),
                    tests: (p.testIds || []).map((id) => nameById.get(String(id))).filter(Boolean),
                    price: p.price || 0, priceB2B: p.price || 0, active: p.isActive !== false,
                })),
                patients: await patientsFor(lab),
            },
        });
    } catch (error) {
        console.error('App bootstrap error:', error);
        res.status(500).json({ success: false, message: 'Error loading lab data' });
    }
});

// ---------- licence holders <-> the app's single text field ----------
const TITLES = ['Assoc. Prof.', 'Asst. Prof.', 'Prof.', 'Dr.', 'Mr.', 'Ms.', 'أ.م.د.', 'أ.د.', 'م.د.', 'د.', 'السيدة', 'السيد'];

function holdersToText(list) {
    return (list || []).map((h) => [[h.title, h.name].filter(Boolean).join(' '), h.specialty].filter(Boolean).join(' · ')).join('\n');
}

// "Dr. Ahmed Hamdoon Ahmed · Bacteriologist" per line (or comma separated).
function textToHolders(text) {
    return cleanLicenseHolders(String(text || '').split(/\n|,|،/).map((line) => {
        let rest = line.trim();
        let title = '';
        const t = TITLES.find((x) => rest.startsWith(x + ' ') || rest === x);
        if (t) { title = t; rest = rest.slice(t.length).trim(); }
        const [name, ...spec] = rest.split(/\s+[·•\-–]\s+/);
        return { title, name, specialty: spec.join(' ') };
    }));
}

// ---------- finance in the shape of the app's finance card ----------
router.get('/api/app/finance', async (req, res) => {
    try {
        const s = await financeSummary(req.lab._id, req.query.period || 'month');
        // Six bars: the period split into six equal parts.
        const chunk = (arr) => {
            const n = arr.length, size = Math.ceil(n / 6) || 1, out = [];
            for (let i = 0; i < 6; i++) out.push(arr.slice(i * size, (i + 1) * size).reduce((a, b) => a + b, 0));
            return out;
        };
        const recent = await Order.find({ labId: req.lab._id, status: { $ne: 'cancelled' }, orderCategory: { $ne: 'prescription' } })
            .populate('patientId', 'name')
            .sort({ createdAt: -1 })
            .limit(5)
            .lean();
        res.json({
            success: true,
            data: {
                totals: s.totals,
                byCategory: s.byCategory,
                expenses: s.expenses.map((e) => ({ category: e.category, note: e.note, amount: e.amount, date: e.date })),
                debts: s.debts.map((d) => ({ name: d.name, amount: d.amount, orderId: String(d._id) })),
                bars: { income: chunk(s.series.income), expenses: chunk(s.series.expenses) },
                invoices: recent.map((o) => ({
                    code: o.qrCode,
                    name: o.beneficiary?.isForOtherPerson ? o.beneficiary.name : (o.patientId?.name || ''),
                    amount: labShare(o),
                    paid: o.payment?.status === 'paid',
                })),
            },
        });
    } catch (error) {
        console.error('App finance error:', error);
        res.status(500).json({ success: false, message: 'Error loading finance' });
    }
});

// ---------- lab details edited in the app (saved as the user types) ----------
router.patch('/api/app/lab', async (req, res) => {
    try {
        const lab = await Lab.findById(req.lab._id);
        const b = req.body || {};
        const clip = (v, n) => String(v).replace(/\s+/g, ' ').trim().slice(0, n);
        if (typeof b.name === 'string' && clip(b.name, 120)) lab.name = clip(b.name, 120);
        if (typeof b.phone === 'string' && clip(b.phone, 30)) lab.phone = clip(b.phone, 30);
        if (typeof b.address === 'string' && clip(b.address, 200)) lab.address = clip(b.address, 200);
        if (typeof b.licenseOwners === 'string') lab.licenseHolders = textToHolders(b.licenseOwners);
        lab.lastUpdatedBy = req.user._id;
        await lab.save();
        res.json({ success: true, data: { name: lab.name, phone: lab.phone, address: lab.address, licenseOwners: holdersToText(lab.licenseHolders) } });
    } catch (error) {
        if (error.name === 'ValidationError') return res.status(400).json({ success: false, message: error.message });
        console.error('App lab update error:', error);
        res.status(500).json({ success: false, message: 'Error saving lab details' });
    }
});

// ---------- samples sent to other labs ----------
function toReferral(t) {
    const done = t.status === 'completed';
    const eta = t.expectedResultAt ? new Date(t.expectedResultAt) : null;
    return {
        id: String(t._id),
        patient: t.patientName || '',
        test: (t.tests || []).map((x) => x.testName).filter(Boolean).join(', ') || t.testsDescription || '',
        lab: t.externalLab?.name || '',
        status: done ? 'Completed' : 'Sent',
        eta: eta ? `${eta.getDate()}/${eta.getMonth() + 1}/${eta.getFullYear()}` : '—',
        tracking: t.referenceNumber || t.sampleCode || '',
        step: done ? 3 : 1,
    };
}

router.get('/api/app/transfers', async (req, res) => {
    try {
        const list = await ExternalTransfer.find({ labId: req.lab._id }).sort({ sentAt: -1 }).limit(100).lean();
        const labs = [...new Set(list.map((t) => t.externalLab?.name).filter(Boolean))];
        res.json({ success: true, data: { referrals: list.map(toReferral), labs } });
    } catch (error) {
        console.error('App transfers error:', error);
        res.status(500).json({ success: false, message: 'Error loading transfers' });
    }
});

// Linked to the order when the patient is one of the lab's open orders.
router.post('/api/app/transfers', async (req, res) => {
    try {
        const b = req.body || {};
        const target = { labName: b.labName, notes: b.notes, toLabId: b.toLabId };
        const targetLab = await labTransfers.resolveTargetLab(target, req.lab);
        const fields = buildCommonFields(target, { userId: req.user._id });
        if (target.phone) fields.externalLab.phone = target.phone;
        if (target.address) fields.externalLab.address = target.address;
        fields.labId = req.lab._id;
        let order = null;
        if (b.orderId && /^[a-f0-9]{24}$/i.test(String(b.orderId))) {
            order = await Order.findOne({ _id: b.orderId, labId: req.lab._id, status: { $nin: ['cancelled', 'completed'] } }).populate('patientId', patientFields);
            if (order && await ExternalTransfer.exists({ orderId: order._id })) order = null;
        }
        if (order) {
            const info = decorateOrderWithPatientInfo(order).patientInfo || {};
            // One or more test names (testNames), or a single testName.
            const names = new Set((Array.isArray(b.testNames) ? b.testNames : [b.testName]).map((n) => String(n || '').trim()).filter(Boolean));
            const picked = (order.tests || []).filter((t) => names.has(t.testName)).map((t) => String(t.testId));
            fields.orderId = order._id;
            fields.sampleCode = order.qrCode;
            fields.patientName = info.name || 'Unknown';
            fields.patientPhone = info.phone || undefined;
            fields.patientGender = info.gender || null;
            fields.patientAge = Number.isInteger(info.age) ? info.age : null;
            fields.tests = resolveOrderTests(order, picked);
        } else {
            const name = String(b.patientName || '').trim();
            if (!name) return res.status(400).json({ success: false, message: 'Patient name is required' });
            fields.sampleCode = ExternalTransfer.generateSampleCode();
            fields.patientName = name.slice(0, 120);
            const typed = Array.isArray(b.testNames) && b.testNames.length ? b.testNames.join(', ') : b.testName;
            if (typed) fields.testsDescription = String(typed).slice(0, 300);
        }
        labTransfers.applyTargetAndPrice(fields, b, targetLab);
        const transfer = await ExternalTransfer.create(fields);
        await labTransfers.notifySent(transfer, req.lab);
        res.status(201).json({ success: true, data: { referral: toReferral(transfer.toObject ? transfer.toObject() : transfer) } });
    } catch (error) {
        if (error instanceof ExternalTransferError) return res.status(error.statusCode).json({ success: false, message: error.message });
        console.error('App transfer error:', error);
        res.status(500).json({ success: false, message: 'Error saving the transfer' });
    }
});

// ---------- tests and packages edited in the app ----------
function num(v) {
    if (v === null || v === undefined || String(v).trim() === '') return null;
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
}

// Create (no id) or update a lab test from the app's CatalogTest shape.
router.put('/api/app/tests', async (req, res) => {
    try {
        const b = req.body || {};
        const lab = await Lab.findById(req.lab._id);
        let test = b.id ? lab.tests.id(b.id) : null;
        if (b.id && !test) return res.status(404).json({ success: false, message: 'Test not found' });
        const name = String(b.name || '').trim().slice(0, 120);
        if (!test) {
            if (!name) return res.status(400).json({ success: false, message: 'Test name is required' });
            if (lab.tests.some((t) => t.name.toLowerCase() === name.toLowerCase())) {
                return res.status(409).json({ success: false, message: 'A test with this name already exists', code: 'duplicate' });
            }
            lab.tests.push({ name, code: `T-${Date.now().toString(36).toUpperCase()}`, price: Math.max(0, Math.round(num(b.price) || 0)), category: 'General' });
            test = lab.tests[lab.tests.length - 1];
        }
        if (num(b.price) !== null) test.price = Math.max(0, Math.round(num(b.price)));
        if (num(b.priceB2B) !== null) test.priceB2B = Math.max(0, Math.round(num(b.priceB2B)));
        if (typeof b.category === 'string' && TEST_CATEGORIES.includes(b.category)) test.category = b.category;
        if (typeof b.on === 'boolean') test.isActive = b.on;
        if (typeof b.units === 'string') test.unit = b.units.trim().slice(0, 40);
        if (typeof b.normalText === 'string') test.normalText = b.normalText.trim().slice(0, 200);
        if (Array.isArray(b.ranges)) {
            test.ranges = b.ranges.slice(0, 20).map((r) => ({
                gender: ['Both', 'Male', 'Female'].includes(r.gender) ? r.gender : 'Both',
                ageFrom: Math.max(0, num(r.ageFrom) ?? 0),
                ageTo: Math.max(0, num(r.ageTo) ?? 120),
                ageUnit: ['Y', 'M', 'D'].includes(r.ageUnit) ? r.ageUnit : 'Y',
                min: num(r.min),
                max: num(r.max),
            }));
        }
        test.lastUpdatedBy = req.user._id;
        await lab.save();
        res.json({ success: true, data: { test: toCatalog([test.toObject ? test.toObject() : test])[0] } });
    } catch (error) {
        if (error.name === 'ValidationError') return res.status(400).json({ success: false, message: error.message });
        console.error('App test save error:', error);
        res.status(500).json({ success: false, message: 'Error saving the test' });
    }
});

// Create (no id or a local id) or update a package; tests come as names.
router.put('/api/app/packages', async (req, res) => {
    try {
        const b = req.body || {};
        const byName = new Map((req.lab.tests || []).map((t) => [t.name, String(t._id)]));
        (req.lab.tests || []).forEach((t) => { if (t.nameAr) byName.set(t.nameAr, String(t._id)); });
        const testIds = [...new Set((Array.isArray(b.tests) ? b.tests : []).map((n) => byName.get(n)).filter(Boolean))];
        const isServerId = /^[a-f0-9]{24}$/i.test(String(b.id || ''));
        let pkg = isServerId ? await Package.findOne({ _id: b.id, labId: req.lab._id }) : null;
        if (isServerId && !pkg) return res.status(404).json({ success: false, message: 'Package not found' });
        if (!pkg) {
            const name = String(b.name || '').trim();
            if (!name || testIds.length < 2) {
                return res.status(400).json({ success: false, message: 'A package needs a name and at least 2 tests', code: 'packageTests' });
            }
            pkg = new Package({ labId: req.lab._id, name: name.slice(0, 120), testIds, price: Math.max(0, Math.round(num(b.price) || 0)) });
        }
        if (typeof b.name === 'string' && b.name.trim()) pkg.name = b.name.trim().slice(0, 120);
        if (Array.isArray(b.tests)) {
            if (testIds.length < 2) return res.status(400).json({ success: false, message: 'A package needs at least 2 tests', code: 'packageTests' });
            pkg.testIds = testIds;
        }
        if (num(b.price) !== null) pkg.price = Math.max(0, Math.round(num(b.price)));
        if (typeof b.category === 'string' && PACKAGE_CATEGORIES.includes(b.category)) pkg.category = b.category;
        if (typeof b.active === 'boolean') pkg.isActive = b.active;
        await pkg.save();
        res.json({ success: true, data: { id: String(pkg._id) } });
    } catch (error) {
        if (error.name === 'ValidationError') return res.status(400).json({ success: false, message: error.message });
        console.error('App package save error:', error);
        res.status(500).json({ success: false, message: 'Error saving the package' });
    }
});

router.get('/api/app/patients', async (req, res) => {
    try {
        res.json({ success: true, data: { patients: await patientsFor(req.lab) } });
    } catch (error) {
        console.error('App patients error:', error);
        res.status(500).json({ success: false, message: 'Error loading patients' });
    }
});

module.exports = router;
module.exports.toAppPatient = toAppPatient;
module.exports.toCatalog = toCatalog;
module.exports.textToHolders = textToHolders;
module.exports.holdersToText = holdersToText;
module.exports.toReferral = toReferral;
