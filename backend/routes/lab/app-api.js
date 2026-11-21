// Data for the lab mobile app, in the shapes the app already uses
// (Patient, CatalogTest, LabPackage). Same auth and permissions as the
// dashboard: the app signs in with /api/auth/login and sends the token.
const express = require('express');
const mongoose = require('mongoose');
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
const receipt = require('../../services/receiptLinkService');
const { baseUrl } = require('../../helpers/base-url');
const { resolvePatient, birthDateFromAge, WalkInError, createWalkInOrder } = require('../../services/walkInOrderService');

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

// "LG-MWNVORLL-NQZAOC" -> "LG-NQZAOC" (short enough for a receipt line).
function shortCode(code) {
    const parts = String(code || '').split('-').filter(Boolean);
    if (parts.length < 2) return String(code || '');
    return `${parts[0]}-${parts[parts.length - 1]}`;
}

function appStatus(order) {
    if (order.status === 'completed') return 'Completed';
    if (order.orderType === 'walk_in' && ['pending', 'partial'].includes(order.payment?.status)) return 'Payment Pending';
    return 'Pending';
}

// Collected so far: paidAmount when recorded, otherwise all or nothing by status.
// Only walk-in orders are paid at the lab; other orders (home collection) are
// settled with the nurse, so they never show as a debt to the lab.
function paidAmountOf(o) {
    if (o.orderType !== 'walk_in') return o.pricing?.total || 0;
    if (typeof o.payment?.paidAmount === 'number') return o.payment.paidAmount;
    return o.payment?.status === 'paid' ? (o.pricing?.total || 0) : 0;
}

function toAppPatient(order, base = '') {
    const o = decorateOrderWithPatientInfo(order);
    const info = o.patientInfo || {};
    const created = new Date(o.createdAt);
    const results = {};
    const resultMeta = {};
    for (const v of o.results?.values || []) {
        if (v.value) results[v.testName] = v.value;
        if (v.custom) resultMeta[v.testName] = { unit: v.unit || '', range: v.normalText || '' };
    }
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
        // for the period statement printed from the home card
        discount: o.pricing?.discount || 0,
        paid: o.orderType !== 'walk_in' || o.payment?.status === 'paid',
        paidAmount: paidAmountOf(o),
        doctor: o.walkIn?.doctor || '',
        mode: company ? 'B2B' : 'B2C',
        company: company || null,
        results,
        resultMeta,
        resultStatus: o.results?.entryStatus || 'none',
        // #patientNo for an account; someone on another's phone gets the order code's short tail.
        permanent: info.patientNo ? `#${info.patientNo}` : shortCode(o.qrCode),
        orderCode: o.qrCode || '',
        orderNo: receipt.receiptCode(o),
        // the short link when the order has a code, the long signed one otherwise
        resultUrl: base ? (o.resultCode ? receipt.shortLink(base, o.resultCode) : receipt.resultLink(base, String(o._id))) : '',
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

async function patientsFor(lab, base = '') {
    const orders = await Order.find({ labId: lab._id, status: { $in: ['at_lab', 'completed'] } })
        .populate('patientId', patientFields)
        .sort({ createdAt: -1 })
        .limit(200);
    // Orders made before short links existed get their code the first time they are listed.
    const missing = orders.filter((o) => !o.resultCode);
    if (missing.length) {
        for (const o of missing) o.resultCode = receipt.newCode(o);
        await Order.bulkWrite(missing.map((o) => ({ updateOne: { filter: { _id: o._id, resultCode: { $exists: false } }, update: { $set: { resultCode: o.resultCode } } } })), { ordered: false })
            .catch((error) => console.warn('Result codes not saved:', error.message));
    }
    return orders.map((o) => toAppPatient(o, base));
}

router.get('/api/app/bootstrap', async (req, res) => {
    try {
        const lab = req.lab;
        const packages = await Package.find({ labId: lab._id }).lean();
        const nameById = new Map((lab.tests || []).map((t) => [String(t._id), t.name]));
        res.json({
            success: true,
            data: {
                user: {
                    name: req.user.name || '', phone: req.user.phone || '', email: req.user.email || '', photo: req.user.profilePicture || '',
                    isOwner: Boolean(req.isLabOwner), roleKey: req.isLabOwner ? 'owner' : (req.user.labStaff?.roleKey || ''),
                    permissions: req.labPermissions || [],
                },
                lab: labForApp(lab),
                catalog: toCatalog(lab.tests),
                packages: packages.map((p) => ({
                    id: String(p._id), code: '', name: p.nameAr || p.name, category: p.category || 'General', aliases: [p.name, p.nameAr].filter(Boolean),
                    tests: (p.testIds || []).map((id) => nameById.get(String(id))).filter(Boolean),
                    price: p.price || 0, priceB2B: p.price || 0, active: p.isActive !== false,
                })),
                patients: await patientsFor(lab, baseUrl(req)),
            },
        });
    } catch (error) {
        console.error('App bootstrap error:', error);
        res.status(500).json({ success: false, message: 'Error loading lab data' });
    }
});

// The lab's details as the app's "Lab data" and "Reports" sections show them
// (the same fields as the web settings page).
function labForApp(lab) {
    return {
        // "L101": the lab's permanent number (archives, support).
        labCode: lab.labNo ? `L${lab.labNo}` : '',
        name: lab.name || '', nameAr: lab.nameAr || '', phone: lab.phone || '', email: lab.email || '', website: lab.website || '',
        description: lab.description || '', address: lab.address || '', city: lab.city || '', logo: lab.logo || '',
        licenseOwners: holdersToText(lab.licenseHolders),
        licenseHolders: (lab.licenseHolders || []).map((h) => ({ title: h.title || '', name: h.name || '', specialty: h.specialty || '' })),
        // The "Powered by LabGo" footer can only be removed from the LabGo admin panel.
        platformFooter: !lab.reportBranding?.hidePlatformFooter,
    };
}

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

// ---------- pay off what a patient owes (pay later / partial payment) ----------
// body: { amount } — omitted or more than what is owed settles the whole debt.
router.post('/api/app/orders/:id/pay', async (req, res) => {
    try {
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) return res.status(404).json({ success: false, message: 'Not found' });
        const order = await Order.findOne({ _id: req.params.id, labId: req.lab._id, orderType: 'walk_in' });
        if (!order) return res.status(404).json({ success: false, message: 'Not found' });
        const total = order.pricing?.total || 0;
        const already = paidAmountOf(order);
        const owed = Math.max(0, total - already);
        if (owed <= 0) return res.status(409).json({ success: false, message: 'Already paid', code: 'paid' });
        const raw = req.body?.amount;
        const amount = raw === undefined || raw === null || raw === '' ? owed : Math.round(Number(raw));
        if (!(amount > 0)) return res.status(400).json({ success: false, message: 'Enter an amount', code: 'amount' });
        const paid = Math.min(total, already + amount);
        const now = new Date();
        order.payment.paidAmount = paid;
        order.payment.status = paid >= total ? 'paid' : 'partial';
        order.payment.paidAt = now;
        order.payment.collectedBy = req.user?._id;
        if (paid >= total) order.paymentCollected = { collected: true, collectedAt: now, collectedBy: req.user?._id };
        await order.save();
        const fresh = await Order.findById(order._id).populate('patientId', 'name phone gender birthDate patientNo').lean();
        res.json({ success: true, data: toAppPatient(fresh, baseUrl(req)) });
    } catch (error) {
        console.error('Pay off error:', error);
        res.status(500).json({ success: false, message: 'Error saving the payment' });
    }
});

// ---------- edit a walk-in patient's details (name, phone, gender, age) ----------
// A placeholder account this lab made is renamed in place; otherwise the order is
// re-pointed at the account for the phone (or a "someone else" beneficiary), so a
// registered patient's own account is never rewritten by a lab.
router.patch('/api/app/orders/:id/patient', async (req, res) => {
    try {
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) return res.status(404).json({ success: false, message: 'Not found' });
        const order = await Order.findOne({ _id: req.params.id, labId: req.lab._id, orderType: 'walk_in', status: { $ne: 'cancelled' } }).populate('patientId');
        if (!order) return res.status(404).json({ success: false, message: 'Not found' });
        const b = req.body || {};
        const name = String(b.name || '').trim().slice(0, 120);
        if (!name) return res.status(400).json({ success: false, message: 'Patient name is required', code: 'name' });
        const gender = ['male', 'female'].includes(b.gender) ? b.gender : null;
        const hasAge = b.age !== undefined && b.age !== null && String(b.age).trim() !== '';
        const birthDate = hasAge ? birthDateFromAge(b.age, ['Y', 'M', 'D'].includes(b.ageUnit) ? b.ageUnit : 'Y') : undefined;
        const user = order.patientId;
        const forOther = order.beneficiary?.isForOtherPerson === true;
        const samePhone = (() => {
            const now = String((forOther ? order.beneficiary.phone : user?.phone) || '').replace(/\D/g, '').slice(-10);
            return now && now === String(b.phone || '').replace(/\D/g, '').slice(-10);
        })();
        if (samePhone && forOther) {
            order.beneficiary.name = name;
            if (gender) order.beneficiary.gender = gender;
            if (birthDate !== undefined) order.beneficiary.birthDate = birthDate;
        } else if (samePhone && user?.labPlaceholder && String(user.createdByLabId) === String(req.lab._id)) {
            user.name = name;
            if (gender) user.gender = gender;
            if (birthDate !== undefined) user.birthDate = birthDate;
            await user.save();
        } else {
            const r = await resolvePatient(req.lab, { name, phone: b.phone, gender, birthDate: birthDate ?? user?.birthDate ?? null });
            order.patientId = r.user._id;
            order.beneficiary = r.beneficiary || { isForOtherPerson: false };
        }
        await order.save();
        const fresh = await Order.findById(order._id).populate('patientId', patientFields);
        res.json({ success: true, data: toAppPatient(fresh, baseUrl(req)) });
    } catch (error) {
        if (error instanceof WalkInError) return res.status(error.status).json({ success: false, message: error.message });
        console.error('Edit patient error:', error);
        res.status(500).json({ success: false, message: 'Error saving the patient' });
    }
});

// ---------- delete a walk-in order (kept as cancelled, out of lists and finance) ----------
router.delete('/api/app/orders/:id', async (req, res) => {
    try {
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) return res.status(404).json({ success: false, message: 'Not found' });
        const order = await Order.findOne({ _id: req.params.id, labId: req.lab._id, orderType: 'walk_in', status: { $ne: 'cancelled' } });
        if (!order) return res.status(404).json({ success: false, message: 'Not found' });
        order.status = 'cancelled';
        order.cancellation = { reason: String(req.body?.reason || 'Deleted by the lab').slice(0, 300), cancelledBy: req.user?._id, cancelledAt: new Date() };
        await order.save();
        res.json({ success: true, data: { id: String(order._id) } });
    } catch (error) {
        console.error('Delete order error:', error);
        res.status(500).json({ success: false, message: 'Error deleting the order' });
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
        if (typeof b.email === 'string' && /^\S+@\S+\.\S+$/.test(b.email.trim())) lab.email = clip(b.email, 120).toLowerCase();
        if (typeof b.website === 'string') lab.website = clip(b.website, 200);
        if (typeof b.description === 'string') lab.description = String(b.description).trim().slice(0, 1000);
        if (Array.isArray(b.licenseHolders)) lab.licenseHolders = cleanLicenseHolders(b.licenseHolders);
        else if (typeof b.licenseOwners === 'string') lab.licenseHolders = textToHolders(b.licenseOwners);
        lab.lastUpdatedBy = req.user._id;
        await lab.save();
        res.json({ success: true, data: labForApp(lab) });
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
        gender: t.patientGender || '',
        age: Number.isInteger(t.patientAge) ? t.patientAge : null,
        test: (t.tests || []).map((x) => x.testName).filter(Boolean).join(', ') || t.testsDescription || '',
        lab: t.externalLab?.name || '',
        status: done ? 'Completed' : 'Sent',
        eta: eta ? `${eta.getDate()}/${eta.getMonth() + 1}/${eta.getFullYear()}` : '—',
        tracking: t.trackingCode || t.referenceNumber || t.sampleCode || '',
        step: done ? 3 : 1,
        orderId: t.orderId ? String(t.orderId) : null,
        onLabGo: Boolean(t.toLabId),
        sentAt: t.sentAt || null,
        tests: (t.tests || []).map((x) => x.testName).filter(Boolean).length
            ? (t.tests || []).map((x) => x.testName).filter(Boolean)
            : String(t.testsDescription || '').split(/[,،]/).map((s) => s.trim()).filter(Boolean),
        // Results however they came back: typed here, by the receiving lab, or from the QR page.
        results: (t.receiverResults?.values || []).filter((v) => v.value).map((v) => ({
            test: v.testName, value: v.value, unit: v.unit || '', range: v.normalText || (v.min != null && v.max != null ? `${v.min} - ${v.max}` : ''), flag: v.flag || '',
        })),
        resultFile: t.resultFileUrl || '',
        resultSource: t.resultSource || '',
        // Used by the web dashboard's tracking cards (the app ignores them).
        receivedAt: t.receivedAt || null,
        forwardedAt: t.forwardedAt || null,
        price: typeof t.price === 'number' ? t.price : null,
        sampleCode: t.sampleCode || '',
        labPhone: t.externalLab?.phone || '',
    };
}

router.get('/api/app/transfers', async (req, res) => {
    try {
        const list = await ExternalTransfer.find({ labId: req.lab._id }).sort({ sentAt: -1 }).limit(100).lean();
        const labs = [...new Set(list.map((t) => t.externalLab?.name).filter(Boolean))];
        // The receiving lab's unit and normal range for each sent test (prefilled, editable).
        const targetIds = [...new Set(list.map((t) => t.toLabId && String(t.toLabId)).filter(Boolean))];
        const targets = new Map((await Lab.find({ _id: { $in: targetIds } }).select('tests').lean()).map((l) => [String(l._id), l]));
        const { pickRange } = require('../../helpers/result-ranges');
        const referrals = list.map((t) => {
            const r = toReferral(t);
            const lab = t.toLabId && targets.get(String(t.toLabId));
            if (lab) {
                r.refs = {};
                for (const name of r.tests) {
                    const lt = labTransfers.matchTest(lab, name);
                    if (!lt) continue;
                    const range = pickRange(lt.ranges, { gender: t.patientGender, age: t.patientAge });
                    const text = lt.normalText || (range && range.min != null && range.max != null ? `${range.min} - ${range.max}` : '');
                    if (lt.unit || text) r.refs[name] = { unit: lt.unit || '', range: text };
                }
            }
            return r;
        });
        res.json({ success: true, data: { referrals, labs } });
    } catch (error) {
        console.error('App transfers error:', error);
        res.status(500).json({ success: false, message: 'Error loading transfers' });
    }
});

// Delete a transfer this lab made (swipe in the tracking list). The patient's
// order stays; a receiving lab on LabGo is told the sample was withdrawn.
router.delete('/api/app/transfers/:id', async (req, res) => {
    try {
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) return res.status(404).json({ success: false, message: 'Not found' });
        const t = await ExternalTransfer.findOne({ _id: req.params.id, labId: req.lab._id });
        if (!t) return res.status(404).json({ success: false, message: 'Not found' });
        await ExternalTransfer.deleteOne({ _id: t._id });
        await require('../../models/Notification').deleteMany({ 'data.transferId': String(t._id) }).catch(() => {});
        if (t.toLabId) {
            await require('../../services/labNotify').notifyLab(t.toLabId, {
                title: 'تم سحب عينة مرسلة',
                body: `${req.lab.name} ألغى إرسال العينة ${t.trackingCode || t.sampleCode} (${t.patientName})`,
                data: { type: 'transfer_withdrawn', sampleCode: t.trackingCode || t.sampleCode },
            });
        }
        res.json({ success: true, data: { id: String(t._id) } });
    } catch (error) {
        console.error('Delete transfer error:', error);
        res.status(500).json({ success: false, message: 'Error deleting the transfer' });
    }
});

// The sending lab types the results of a sample it sent (as the other lab
// reported them) — also when that lab is on LabGo and has not entered them yet. body: { values: [{ testName, value, unit, range }] }
router.put('/api/app/transfers/:id/results', async (req, res) => {
    try {
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) return res.status(404).json({ success: false, message: 'Not found' });
        const t = await ExternalTransfer.findOne({ _id: req.params.id, labId: req.lab._id });
        if (!t) return res.status(404).json({ success: false, message: 'Not found' });
        const ok = await labTransfers.saveExternalResults(t, req.body?.values, { source: 'lab', userId: req.user?._id });
        if (!ok) return res.status(400).json({ success: false, message: 'Enter at least one result', code: 'missing' });
        res.json({ success: true, data: { referral: toReferral(t.toObject()) } });
    } catch (error) {
        console.error('Transfer results error:', error);
        res.status(500).json({ success: false, message: 'Error saving the results' });
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
            // Another test of the same order can be sent; the same tests twice cannot.
            if (order) {
                const wanted = new Set((Array.isArray(b.testNames) ? b.testNames : [b.testName]).map((n) => String(n || '').trim()).filter(Boolean));
                const earlier = await ExternalTransfer.find({ orderId: order._id }).select('tests').lean();
                const sentNames = new Set(earlier.flatMap((t) => (t.tests || []).map((x) => x.testName)));
                if (wanted.size && [...wanted].every((n) => sentNames.has(n))) {
                    return res.status(409).json({ success: false, message: 'These tests were already sent', code: 'alreadySent' });
                }
            }
        }
        // A new patient typed on the send page becomes a normal patient (receipt
        // V0001, results entered the same way), and the sample is sent from that order.
        if (!order) {
            const name = String(b.patientName || '').trim();
            const names = [...new Set((Array.isArray(b.testNames) ? b.testNames : [b.testName]).map((n) => String(n || '').trim()).filter(Boolean))];
            if (!name) return res.status(400).json({ success: false, message: 'Patient name is required' });
            if (!String(b.patientPhone || '').replace(/\D/g, '')) {
                return res.status(400).json({ success: false, message: 'Enter the patient phone number', code: 'phone' });
            }
            if (!names.length) return res.status(400).json({ success: false, message: 'Choose at least one test', code: 'tests' });
            // The lab's own test when it has one (its price), otherwise a referred-only line.
            const testLines = names.map((n) => {
                const t = labTransfers.matchTest(req.lab, n);
                return t
                    ? { testId: t._id, testName: t.name, testCode: t.code || 'REF', category: t.category || 'General', price: t.price || 0 }
                    : { testId: new mongoose.Types.ObjectId(), testName: n.slice(0, 120), testCode: 'REF', category: 'Referred', price: 0 };
            });
            const gender = String(b.patientGender || '').toLowerCase();
            order = await createWalkInOrder(req.lab, req.user._id, {
                name, phone: b.patientPhone, gender: ['male', 'female'].includes(gender) ? gender : undefined,
                age: b.patientAge, ageUnit: 'Y', testLines, sampleType: 'blood',
            });
            await order.populate('patientId', patientFields);
            b.testNames = testLines.map((t) => t.testName);
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
            const gender = String(b.patientGender || '').toLowerCase();
            if (gender === 'male' || gender === 'female') fields.patientGender = gender;
            const age = parseInt(b.patientAge, 10);
            if (Number.isInteger(age) && age >= 0 && age <= 130) fields.patientAge = age;
            const typed = Array.isArray(b.testNames) && b.testNames.length ? b.testNames.join(', ') : b.testName;
            if (typed) fields.testsDescription = String(typed).slice(0, 300);
        }
        labTransfers.applyTargetAndPrice(fields, b, targetLab);
        const transfer = await ExternalTransfer.create(fields);
        await labTransfers.notifySent(transfer, req.lab);
        res.status(201).json({ success: true, data: { referral: toReferral(transfer.toObject ? transfer.toObject() : transfer) } });
    } catch (error) {
        if (error instanceof ExternalTransferError) return res.status(error.statusCode).json({ success: false, message: error.message });
        if (error instanceof WalkInError) return res.status(error.status).json({ success: false, message: error.message });
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
        res.json({ success: true, data: { patients: await patientsFor(req.lab, baseUrl(req)) } });
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
module.exports.labForApp = labForApp;
module.exports.toReferral = toReferral;
