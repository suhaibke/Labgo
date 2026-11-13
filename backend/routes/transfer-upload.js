// Public pages opened from the QR code on a shipping label: the receiving lab
// (not on LabGo) uploads the result, and the label can be opened for printing.
// Access needs the per-transfer key from the label; nothing else is exposed.
const express = require('express');
const multer = require('multer');
const mongoose = require('mongoose');
const ExternalTransfer = require('../models/ExternalTransfer');
const Lab = require('../models/Lab');
const r2Service = require('../services/r2Service');
const transferLabel = require('../services/transferLabelService');
const { baseUrl } = require('../helpers/base-url');

const router = express.Router();
const TYPES = { 'application/pdf': '.pdf', 'image/jpeg': '.jpg', 'image/png': '.png' };
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 10 * 1024 * 1024, files: 1 },
    fileFilter: (req, file, cb) => cb(null, Boolean(TYPES[file.mimetype])),
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
        code: transfer.sampleCode,
        sendingLab: lab?.name || '',
        patient: maskName(transfer.patientName),
        tests: (transfer.tests || []).map((t) => t.testName).filter(Boolean).join(', ') || transfer.testsDescription || '',
        toLab: transfer.externalLab?.name || '',
        error: null,
        ...extra,
    };
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
        next();
    });
}, async (req, res) => {
    headers(res);
    try {
        const transfer = await findTransfer(req);
        if (!transfer) return res.status(404).render('reports/transfer-upload', { state: 'invalid' });
        // One upload per sample: a received result cannot be replaced from the link.
        if (transfer.status === 'completed') return res.render('reports/transfer-upload', await pageModel(transfer));
        if (req.uploadError || !req.file) {
            return res.status(400).render('reports/transfer-upload', await pageModel(transfer, {
                error: req.uploadError || 'اختر ملف PDF أو صورة · Choose a PDF or a photo',
            }));
        }
        const filename = r2Service.generateUniqueFilename(`${transfer.sampleCode}${TYPES[req.file.mimetype]}`, 'ext-upload-');
        const uploaded = await r2Service.uploadBuffer(req.file.buffer, r2Service.r2Config.paths.results, filename, { contentType: req.file.mimetype });

        transfer.status = 'completed';
        transfer.completedAt = new Date();
        transfer.resultFileUrl = uploaded.url;
        transfer.resultSource = 'external_link';
        transfer.externalUpload = {
            uploadedAt: new Date(),
            uploaderName: String(req.body?.uploaderName || '').trim().slice(0, 120),
            note: String(req.body?.note || '').trim().slice(0, 1000),
        };
        await transfer.save();
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
