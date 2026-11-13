// Shipping label for a sample sent to another lab: same design as the lab
// app's label, with a real barcode (sample code) and a real QR code that lets
// the receiving lab upload the result when it is not on LabGo.
const path = require('path');
const crypto = require('crypto');
const ejs = require('ejs');
const QRCode = require('qrcode');
const bwipjs = require('bwip-js');
const { fontFaces, renderPdf } = require('./reportPdfService');

const TEMPLATE = path.join(__dirname, '../views/reports/transfer-label.ejs');
const SECRET = process.env.REPORT_SIGNING_SECRET || process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788';
const SIZE = { width: '100mm', height: '70mm' };

const TEXT = {
    en: { title: 'Shipping Label', sending: 'Sending Lab', receiving: 'Receiving Lab', date: 'Date', eta: 'ETA',
        note: 'QR is used to upload result if receiving lab is NOT registered in system', ref: 'Ref.', dir: 'ltr' },
    ar: { title: 'ملصق الشحن', sending: 'المختبر المرسل', receiving: 'المختبر المستلم', date: 'التاريخ', eta: 'الوصول المتوقع',
        note: 'يُستخدم QR لرفع النتيجة إذا كان المختبر المستلم غير مسجل', ref: 'المرجع', dir: 'rtl' },
    ku: { title: 'لەیبڵی ناردن', sending: 'تاقیگەی نێرەر', receiving: 'تاقیگەی وەرگر', date: 'بەروار', eta: 'کاتی گەیشتن',
        note: 'QR بۆ بەرزکردنەوەی ئەنجام بەکاردێت ئەگەر تاقیگەی وەرگر نەچووەتە ناو سیستەم', ref: 'ژمارە', dir: 'rtl' },
};

// Per-transfer secret used in the QR link (and the public label link).
function key(transfer) {
    return crypto.createHmac('sha256', SECRET).update(`transfer:${transfer._id}:${transfer.sampleCode}`).digest('hex').slice(0, 20);
}

function checkKey(transfer, k) {
    const expected = key(transfer);
    const given = String(k || '');
    return given.length === expected.length && crypto.timingSafeEqual(Buffer.from(given), Buffer.from(expected));
}

function base(baseUrl) { return String(baseUrl || '').replace(/\/+$/, ''); }
function uploadUrl(baseUrl, transfer) { return `${base(baseUrl)}/r/t/${transfer._id}?k=${key(transfer)}`; }
function publicLabelUrl(baseUrl, transfer, lang) { return `${base(baseUrl)}/r/t/${transfer._id}/label?k=${key(transfer)}&lang=${lang || 'en'}`; }

function fmtDate(d) {
    if (!d) return '—';
    const x = new Date(d);
    if (Number.isNaN(x.getTime())) return '—';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return `${x.getDate()} ${m[x.getMonth()]} ${x.getFullYear()}`;
}

function testsText(t) {
    return (t.tests || []).map((x) => x.testName).filter(Boolean).join(', ') || t.testsDescription || '';
}

async function codes(baseUrl, transfer) {
    // Transparent background: the label (and the app) draw the white box.
    const qrSvg = await QRCode.toString(uploadUrl(baseUrl, transfer), { type: 'svg', margin: 0, errorCorrectionLevel: 'M', color: { dark: '#000000', light: '#0000' } });
    const barcodeSvg = bwipjs.toSVG({ bcid: 'code128', text: String(transfer.sampleCode), height: 10, scale: 2, includetext: false, paddingwidth: 0, paddingheight: 0 });
    return { qrSvg, barcodeSvg };
}

// Everything the label shows; the app draws it natively from this.
async function labelData({ transfer, lab, baseUrl, lang = 'en' }) {
    const { qrSvg, barcodeSvg } = await codes(baseUrl, transfer);
    return {
        code: transfer.sampleCode,
        reference: transfer.referenceNumber || '',
        patient: transfer.patientName || '',
        tests: testsText(transfer),
        fromLab: lab?.name || '',
        toLab: transfer.externalLab?.name || '',
        date: fmtDate(transfer.sentAt),
        eta: fmtDate(transfer.expectedResultAt),
        qrSvg,
        barcodeSvg,
        uploadUrl: uploadUrl(baseUrl, transfer),
        printUrl: publicLabelUrl(baseUrl, transfer, lang),
    };
}

async function labelHtml({ transfer, lab, baseUrl, lang = 'en', autoPrint = false }) {
    const data = await labelData({ transfer, lab, baseUrl, lang });
    const t = TEXT[lang] || TEXT.en;
    return ejs.renderFile(TEMPLATE, { d: data, t, lang: TEXT[lang] ? lang : 'en', fontFaces: fontFaces(), autoPrint });
}

async function labelPdf(args) {
    const html = await labelHtml({ ...args, autoPrint: false });
    return renderPdf(html, { size: SIZE });
}

module.exports = { key, checkKey, uploadUrl, labelData, labelHtml, labelPdf, TEXT };
