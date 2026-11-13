// Data for the lab mobile app, in the shapes the app already uses
// (Patient, CatalogTest, LabPackage). Same auth and permissions as the
// dashboard: the app signs in with /api/auth/login and sends the token.
const express = require('express');
const Order = require('../../models/Order');
const Package = require('../../models/Package');
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
            id: String(t._id), name: t.name, price: t.price || 0, priceB2B: t.price || 0,
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
                lab: { name: lab.name || '', phone: lab.phone || '', address: [lab.address, lab.city].filter(Boolean).join(' - '), logo: lab.logo || '' },
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
