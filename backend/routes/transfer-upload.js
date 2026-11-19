// Public pages opened from the QR code on a shipping label: the receiving lab
// (not on LabGo) uploads the result, and the label can be opened for printing.
// Access needs the per-transfer key from the label; nothing else is exposed.
const express = require('express');
const multer = require('multer');
const mongoose = require('mongoose');
const ExternalTransfer = require('../models/ExternalTransfer');
const Lab = require('../models/Lab');
const r2Service = require('../services/r2Service');
const labResultStore = require('../services/labResultStore');
const transferLabel = require('../services/transferLabelService');
const labTransfers = require('../services/labTransferService');
const { baseUrl } = require('../helpers/base-url');

const router = express.Router();
// iPhone photos arrive as HEIC / HEIF; Android often as WebP.
const TYPES = {
    'application/pdf': '.pdf', 'image/jpeg': '.jpg', 'image/png': '.png',
    'image/heic': '.heic', 'image/heif': '.heif', 'image/webp': '.webp',
};
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 10 * 1024 * 1024, files: 1 },
    fileFilter: (req, file, cb) => {
        const ok = Boolean(TYPES[file.mimetype]);
        if (!ok) req.badType = true;
        cb(null, ok);
    },
});

// "Sara Ali Hussein" -> "Sara A. H."
function maskName(name) {
    const parts = String(name || '').trim().split(/\s+/).filter(Boolean);
    if (!parts.length) return '';
    return [parts[0], ...parts.slice(1).map((p) => `${p.charAt(0)}.`)].join(' ');
}

async function findTransfer(req) {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) return null;
    const transfer = await ExternalTransfer.findById(req.params.id);
    if (!transfer || !transferLabel.checkKey(transfer, req.query.k)) return null;
    return transfer;
}

async function pageModel(transfer, extra = {}) {
    const lab = await Lab.findById(transfer.labId).select('name');
    return {
        state: transfer.status === 'completed' ? 'done' : 'form',
        code: transfer.trackingCode || transfer.sampleCode,
        sendingLab: lab?.name || '',
        patient: maskName(transfer.patientName),
        tests: testList(transfer).join(', '),
        testList: testList(transfer),
        toLab: transfer.externalLab?.name || '',
        price: typeof transfer.price === 'number' ? transfer.price.toLocaleString('en-US') : '',
        error: null,
        ...extra,
    };
}

// The tests to fill in: from the order, or the typed description split by commas.
function testList(transfer) {
    const named = (transfer.tests || []).map((t) => t.testName).filter(Boolean);
    if (named.length) return named;
    return String(transfer.testsDescription || '').split(/[,،]/).map((s) => s.trim()).filter(Boolean).slice(0, 30);
}

function headers(res) {
    res.set('Cache-Control', 'no-store');
    res.set('X-Robots-Tag', 'noindex');
    res.set('Referrer-Policy', 'no-referrer');
}

router.get('/r/t/:id', async (req, res) => {
    headers(res);
    try {
        const transfer = await findTransfer(req);
        if (!transfer) return res.status(404).render('reports/transfer-upload', { state: 'invalid' });
        res.render('reports/transfer-upload', await pageModel(transfer));
    } catch (error) {
        console.error('Transfer upload page error:', error);
        res.status(500).render('reports/transfer-upload', { state: 'invalid' });
    }
});

router.post('/r/t/:id', (req, res, next) => {
    upload.single('resultFile')(req, res, (err) => {
        if (err) req.uploadError = err.code === 'LIMIT_FILE_SIZE' ? 'الملف أكبر من 10 ميغا · File is larger than 10 MB' : 'تعذر رفع الملف · Upload failed';
        else if (req.badType) req.uploadError = 'نوع الملف غير مدعوم، أرفق PDF أو صورة · This file type is not supported — attach a PDF or a photo';
        next();
    });
}, async (req, res) => {
    headers(res);
    try {
        const transfer = await findTransfer(req);
        if (!transfer) return res.status(404).render('reports/transfer-upload', { state: 'invalid' });
        // One upload per sample: a received result cannot be replaced from the link.
        if (transfer.status === 'completed') return res.render('reports/transfer-upload', await pageModel(transfer));
        // Typed results (value, unit, normal range per test) and/or a file.
        const b = req.body || {};
        const names = testList(transfer);
        const rows = names.length
            ? names.map((name, i) => ({ testName: name, value: b[`value_${i}`], unit: b[`unit_${i}`], range: b[`range_${i}`] }))
            : [{ testName: String(b.test_0 || 'Result').slice(0, 120), value: b.value_0, unit: b.unit_0, range: b.range_0 }];
        const typed = rows.some((r) => String(r.value || '').trim());
        if (req.uploadError || (!req.file && !typed)) {
            return res.status(400).render('reports/transfer-upload', await pageModel(transfer, {
                error: req.uploadError || 'اكتب النتيجة أو أرفق صورة / ملف · Type the result or attach a photo / file',
                form: b,
            }));
        }
        let fileUrl = null;
        if (req.file) {
            const filename = labResultStore.fileName(transfer.trackingCode || transfer.sampleCode, TYPES[req.file.mimetype]);
            fileUrl = (await r2Service.uploadBuffer(req.file.buffer, await labResultStore.resultsPath(transfer.labId), filename, { contentType: req.file.mimetype })).url;
        }
        transfer.externalUpload = {
            uploadedAt: new Date(),
            uploaderName: transfer.externalLab?.name || '',
            note: String(b.note || '').trim().slice(0, 1000),
        };
        await labTransfers.saveExternalResults(transfer, rows, { source: 'external_link', fileUrl });
        console.log(`QR result received: ${transfer.trackingCode || transfer.sampleCode} (${rows.filter((r) => String(r.value || '').trim()).length} values${fileUrl ? ', file' : ''})`);
        res.render('reports/transfer-upload', await pageModel(transfer));
    } catch (error) {
        console.error('Transfer result upload error:', error);
        res.status(500).render('reports/transfer-upload', { state: 'invalid' });
    }
});

// The label for printing (used by the lab app's "Print Label").
router.get('/r/t/:id/label', async (req, res) => {
    headers(res);
    try {
        const transfer = await findTransfer(req);
        if (!transfer) return res.status(404).send('Not found');
        const lab = await Lab.findById(transfer.labId).select('name');
        const lang = ['en', 'ar', 'ku'].includes(req.query.lang) ? req.query.lang : 'en';
        res.send(await transferLabel.labelHtml({ transfer, lab, baseUrl: baseUrl(req), lang, autoPrint: false }));
    } catch (error) {
        console.error('Public label error:', error);
        res.status(500).send('Error');
    }
});

module.exports = router;
module.exports.maskName = maskName;
