// Result entry for lab orders: enter a value per test, flag it against the
// lab's normal ranges, save as a draft, then approve and send to the patient.
const express = require('express');
const Order = require('../../models/Order');
const Lab = require('../../models/Lab');
const User = require('../../models/User');
const fcmService = require('../../services/fcmService');
const r2Service = require('../../services/r2Service');
const reportPdf = require('../../services/reportPdfService');
const { decorateOrderWithPatientInfo } = require('../../helpers/order-patient-info');
const { pickRange, classify } = require('../../helpers/result-ranges');

const router = express.Router();
const patientFields = 'name phone gender birthDate patientNo';
const EDITABLE = ['at_lab', 'completed'];

function langOf(req) {
    const currentLang = req.cookies?.lang
        || req.headers['accept-language']?.split(',')[0]?.split('-')[0]
        || 'ar';
    return {
        currentLang,
        direction: ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr',
        font: currentLang === 'ar' ? 'Cairo, sans-serif' : 'Inter, sans-serif',
    };
}

function num(v) {
    if (v === null || v === undefined || String(v).trim() === '') return null;
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
}

function findLabTest(lab, orderTest) {
    const tests = lab?.tests || [];
    return tests.find((t) => String(t._id) === String(orderTest.testId))
        || tests.find((t) => orderTest.testCode && t.code === orderTest.testCode)
        || tests.find((t) => t.name === orderTest.testName)
        || null;
}

// One row per ordered test, with the saved value and the range that applies.
function buildRows(order, lab) {
    const saved = order.results?.values || [];
    const patient = order.patientInfo || {};
    return (order.tests || []).map((t) => {
        const prev = saved.find((v) => (v.testId && String(v.testId) === String(t.testId)) || v.testName === t.testName);
        const labTest = findLabTest(lab, t);
        const range = pickRange(labTest?.ranges, patient);
        // An approved report keeps the range it was approved with.
        const useSaved = prev && order.results?.entryStatus === 'approved';
        const min = useSaved ? prev.min : num(range?.min);
        const max = useSaved ? prev.max : num(range?.max);
        const unit = useSaved ? prev.unit : (labTest?.unit || prev?.unit || '');
        const normalText = useSaved ? prev.normalText : (labTest?.normalText || '');
        const value = prev?.value || '';
        return {
            testId: t.testId,
            labTestId: labTest?._id || null,
            testName: t.testName,
            testNameAr: labTest?.nameAr || '',
            category: t.category || labTest?.category || '',
            value,
            unit,
            min,
            max,
            normalText,
            flag: classify(value, min, max),
            hasRange: min !== null || max !== null || Boolean(normalText),
            // Every age/gender group of the lab test, for the range editor.
            ranges: (labTest?.ranges || []).map((r) => ({ gender: r.gender, ageFrom: r.ageFrom, ageTo: r.ageTo, ageUnit: r.ageUnit, min: r.min, max: r.max })),
        };
    });
}

// Public address used in the report's verification QR code.
function baseUrl(req) {
    if (process.env.PUBLIC_BASE_URL) return process.env.PUBLIC_BASE_URL;
    const proto = String(req.headers['x-forwarded-proto'] || req.protocol || 'https').split(',')[0].trim();
    return `${proto}://${req.get('host')}`;
}

// Builds the report PDF from the order as it stands (approved or draft).
async function reportFor(req, order, approverName) {
    const decorated = decorateOrderWithPatientInfo(order);
    return reportPdf.buildReportPdf({
        order: decorated,
        lab: req.lab,
        rows: buildRows(decorated, req.lab),
        approvedBy: approverName,
        baseUrl: baseUrl(req),
    });
}

async function loadOrder(req, res) {
    const order = await Order.findById(req.params.orderId).populate('patientId', patientFields);
    if (!order) {
        res.status(404).json({ success: false, message: 'Order not found' });
        return null;
    }
    if (String(order.labId) !== String(req.lab._id)) {
        res.status(403).json({ success: false, message: 'This order does not belong to your lab' });
        return null;
    }
    return order;
}

function applyValues(order, rows, body, userId) {
    const incoming = Array.isArray(body.values) ? body.values : [];
    const byKey = new Map(incoming.map((v) => [String(v.testId || v.testName), v]));
    const values = rows.map((r) => {
        const v = byKey.get(String(r.testId)) || byKey.get(r.testName);
        const value = v ? String(v.value ?? '').trim().slice(0, 200) : r.value;
        return {
            testId: r.testId,
            testName: r.testName,
            value,
            unit: r.unit,
            min: r.min,
            max: r.max,
            normalText: r.normalText,
            flag: classify(value, r.min, r.max),
        };
    });
    if (!order.results) order.results = {};
    order.results.values = values;
    if (typeof body.comment === 'string') order.results.comment = body.comment.trim().slice(0, 2000);
    order.results.enteredAt = new Date();
    order.results.enteredBy = userId;
    return values;
}

function payload(order, lab) {
    const decorated = decorateOrderWithPatientInfo(order);
    return {
        order: {
            _id: decorated._id,
            qrCode: decorated.qrCode,
            status: decorated.status,
            createdAt: decorated.createdAt,
            patientInfo: decorated.patientInfo,
            results: {
                comment: decorated.results?.comment || '',
                entryStatus: decorated.results?.entryStatus || 'none',
                reportUrl: decorated.results?.reportUrl || null,
                approvedAt: decorated.results?.approvedAt || null,
            },
        },
        rows: buildRows(decorated, lab),
    };
}

router.get('/orders/:orderId/results', async (req, res) => {
    try {
        const order = await Order.findById(req.params.orderId).populate('patientId', patientFields);
        if (!order || String(order.labId) !== String(req.lab._id)) {
            return res.redirect('/lab/orders');
        }
        const data = payload(order, req.lab);
        res.render('dashboard/lab-results-entry', {
            lab: req.lab,
            user: req.user,
            title: req.lab.name,
            ...langOf(req),
            activeSection: 'orders',
            order: data.order,
            rows: data.rows,
            editable: EDITABLE.includes(order.status),
            initialJson: JSON.stringify(data).replace(/</g, '\\u003c'),
        });
    } catch (error) {
        console.error('Results page error:', error);
        res.status(500).render('error', { message: 'Error loading results', error: null });
    }
});

router.get('/api/orders/:orderId/results', async (req, res) => {
    try {
        const order = await loadOrder(req, res);
        if (!order) return;
        res.json({ success: true, data: payload(order, req.lab) });
    } catch (error) {
        console.error('Get results error:', error);
        res.status(500).json({ success: false, message: 'Error loading results' });
    }
});

// Save a draft (called while typing).
router.put('/api/orders/:orderId/results', async (req, res) => {
    try {
        const order = await loadOrder(req, res);
        if (!order) return;
        if (!EDITABLE.includes(order.status)) {
            return res.status(400).json({ success: false, message: 'Results can be entered once the sample is at the lab' });
        }
        const rows = buildRows(decorateOrderWithPatientInfo(order), req.lab);
        applyValues(order, rows, req.body || {}, req.user._id);
        if (order.results.entryStatus !== 'approved') order.results.entryStatus = 'draft';
        await order.save();
        res.json({ success: true, data: payload(order, req.lab) });
    } catch (error) {
        console.error('Save results error:', error);
        res.status(500).json({ success: false, message: 'Error saving results' });
    }
});

// Approve: every test needs a value. Completes the order (when still at the lab)
// and notifies the patient, like the existing complete endpoint.
router.post('/api/orders/:orderId/results/approve', async (req, res) => {
    try {
        const order = await loadOrder(req, res);
        if (!order) return;
        if (!EDITABLE.includes(order.status)) {
            return res.status(400).json({ success: false, message: 'Results can be entered once the sample is at the lab' });
        }
        const rows = buildRows(decorateOrderWithPatientInfo(order), req.lab);
        const values = applyValues(order, rows, req.body || {}, req.user._id);
        const missing = values.filter((v) => !v.value).map((v) => v.testName);
        // A result uploaded as a file (photo / PDF) can stand in for typed values.
        const uploadedReport = typeof req.body?.reportUrl === 'string' && req.body.reportUrl;
        if (missing.length && !uploadedReport) {
            return res.status(400).json({ success: false, message: 'Some tests have no value', missing });
        }
        order.results.entryStatus = 'approved';
        order.results.approvedAt = new Date();
        order.results.approvedBy = req.user._id;

        // The server builds the report unless the caller sent one (dashboard fallback).
        let reportUrl = typeof req.body?.reportUrl === 'string' && req.body.reportUrl ? req.body.reportUrl : null;
        if (!reportUrl) {
            try {
                const pdf = await reportFor(req, order, req.user.name);
                const filename = r2Service.generateUniqueFilename(`${order.qrCode || order._id}.pdf`, 'report-');
                const uploaded = await r2Service.uploadBuffer(pdf, r2Service.r2Config.paths.results, filename, { contentType: 'application/pdf' });
                reportUrl = uploaded.url;
            } catch (error) {
                if (error.code === 'pdfUnavailable') {
                    return res.status(503).json({ success: false, code: 'pdfUnavailable', message: 'The server cannot build PDF reports right now' });
                }
                throw error;
            }
        }

        const wasAtLab = order.status === 'at_lab';
        if (wasAtLab) {
            await order.markCompleted(req.user._id, reportUrl || order.results.reportUrl);
        } else {
            if (reportUrl) order.results.reportUrl = reportUrl;
            await order.save();
        }

        try {
            await fcmService.sendToUser(
                order.patientId?._id || order.patientId,
                wasAtLab ? 'نتائج الفحوصات جاهزة' : 'تم تحديث نتائج فحوصاتك',
                'نتائج فحوصاتك متاحة الآن',
                { type: 'results_ready', orderId: String(order._id) }
            );
        } catch (fcmError) {
            console.error('FCM results notification error:', fcmError);
        }

        res.json({ success: true, data: payload(order, req.lab) });
    } catch (error) {
        console.error('Approve results error:', error);
        res.status(500).json({ success: false, message: 'Error approving results' });
    }
});

// The report PDF (approved, or a DRAFT copy) to view or print.
router.get('/api/orders/:orderId/report.pdf', async (req, res) => {
    try {
        const order = await loadOrder(req, res);
        if (!order) return;
        let approver = '';
        if (order.results?.approvedBy) {
            const u = await User.findById(order.results.approvedBy).select('name');
            approver = u?.name || '';
        }
        const pdf = await reportFor(req, order, approver);
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `inline; filename="${String(order.qrCode || order._id).replace(/[^\w.-]/g, '')}.pdf"`);
        res.setHeader('Cache-Control', 'no-store');
        res.send(pdf);
    } catch (error) {
        if (error.code === 'pdfUnavailable') {
            return res.status(503).json({ success: false, code: 'pdfUnavailable', message: 'The server cannot build PDF reports right now' });
        }
        console.error('Report PDF error:', error);
        res.status(500).json({ success: false, message: 'Error building the report' });
    }
});

// Unit and normal ranges of a lab test (set from the result entry page).
router.put('/api/tests/:testId/reference', async (req, res) => {
    try {
        const lab = await Lab.findById(req.lab._id);
        const test = lab?.tests?.id(req.params.testId);
        if (!test) return res.status(404).json({ success: false, message: 'Test not found' });
        const body = req.body || {};
        if (typeof body.unit === 'string') test.unit = body.unit.trim().slice(0, 40);
        if (typeof body.normalText === 'string') test.normalText = body.normalText.trim().slice(0, 200);
        if (Array.isArray(body.ranges)) {
            test.ranges = body.ranges.slice(0, 20).map((r) => ({
                gender: ['Both', 'Male', 'Female'].includes(r.gender) ? r.gender : 'Both',
                ageFrom: Math.max(0, num(r.ageFrom) ?? 0),
                ageTo: Math.max(0, num(r.ageTo) ?? 120),
                ageUnit: ['Y', 'M', 'D'].includes(r.ageUnit) ? r.ageUnit : 'Y',
                min: num(r.min),
                max: num(r.max),
            }));
        }
        await lab.save();
        res.json({ success: true, data: { unit: test.unit, normalText: test.normalText, ranges: test.ranges } });
    } catch (error) {
        console.error('Save test reference error:', error);
        res.status(500).json({ success: false, message: 'Error saving normal range' });
    }
});

module.exports = router;
module.exports.buildRows = buildRows;
