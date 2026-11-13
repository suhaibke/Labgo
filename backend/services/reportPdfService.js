// Lab result report as a real (vector, searchable) PDF, rendered by headless
// Chromium from views/reports/lab-result-report.ejs. The same file is sent to
// the patient, opened from the dashboard and from the lab app.
//
// Chromium: set PUPPETEER_EXECUTABLE_PATH (the Docker image installs
// /usr/bin/chromium-browser). Without it the common install paths are tried;
// if none exists, PdfUnavailableError is thrown and callers can fall back.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const ejs = require('ejs');
const QRCode = require('qrcode');

const TEMPLATE = path.join(__dirname, '../views/reports/lab-result-report.ejs');
const FONT_DIR = path.join(__dirname, '../assets/fonts');
const PUBLIC_DIR = path.join(__dirname, '../public');
const SECRET = process.env.REPORT_SIGNING_SECRET || process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788';
const CHROME_CANDIDATES = ['/usr/bin/chromium-browser', '/usr/bin/chromium', '/usr/bin/google-chrome', '/opt/pw-browsers/chromium'];
const SAMPLE = { blood: 'Blood', urine: 'Urine', stool: 'Stool', swab: 'Swab', csf: 'CSF' };

class PdfUnavailableError extends Error {
    constructor(message) {
        super(message);
        this.code = 'pdfUnavailable';
    }
}

// ---------- fonts (embedded so every server renders the same) ----------
let fontCss = null;
function fontFaces() {
    if (fontCss) return fontCss;
    const faces = [
        ['Inter', 'Inter-Regular.ttf', 400], ['Inter', 'Inter-SemiBold.ttf', 600], ['Inter', 'Inter-Bold.ttf', 700], ['Inter', 'Inter-ExtraBold.ttf', 800],
        ['IBM Plex Sans Arabic', 'IBMPlexSansArabic-Regular.ttf', 400], ['IBM Plex Sans Arabic', 'IBMPlexSansArabic-SemiBold.ttf', 600],
        ['IBM Plex Sans Arabic', 'IBMPlexSansArabic-Bold.ttf', 700],
    ];
    fontCss = faces.map(([family, file, weight]) => {
        const data = fs.readFileSync(path.join(FONT_DIR, file)).toString('base64');
        return `@font-face{font-family:"${family}";font-weight:${weight};font-style:normal;src:url(data:font/ttf;base64,${data}) format("truetype");}`;
    }).join('\n');
    return fontCss;
}

// ---------- verification link ----------
function signature(orderId, approvedAt) {
    const stamp = approvedAt ? new Date(approvedAt).toISOString() : '';
    return crypto.createHmac('sha256', SECRET).update(`${orderId}:${stamp}`).digest('hex').slice(0, 20);
}

function verifyUrl(baseUrl, orderId, approvedAt) {
    return `${String(baseUrl || '').replace(/\/+$/, '')}/verify-report/${orderId}?s=${signature(orderId, approvedAt)}`;
}

function checkSignature(orderId, approvedAt, sig) {
    const expected = signature(orderId, approvedAt);
    const given = String(sig || '');
    return given.length === expected.length && crypto.timingSafeEqual(Buffer.from(given), Buffer.from(expected));
}

// ---------- logo ----------
async function streamToBuffer(stream) {
    const chunks = [];
    for await (const c of stream) chunks.push(Buffer.from(c));
    return Buffer.concat(chunks);
}

async function logoDataUrl(logo) {
    if (!logo) return null;
    try {
        let buffer = null;
        let type = 'image/png';
        if (/^https?:\/\//.test(logo)) {
            const axios = require('axios');
            const res = await axios.get(logo, { responseType: 'arraybuffer', timeout: 5000, maxContentLength: 2 * 1024 * 1024 });
            buffer = Buffer.from(res.data);
            type = res.headers['content-type'] || type;
        } else if (logo.startsWith('/uploads/')) {
            const r2 = require('./r2Service');
            const file = await r2.getFileStream(logo);
            buffer = await streamToBuffer(file.stream);
            type = file.contentType || type;
        } else {
            const local = path.join(PUBLIC_DIR, path.normalize(logo).replace(/^(\.\.[/\\])+/, ''));
            if (!local.startsWith(PUBLIC_DIR) || !fs.existsSync(local)) return null;
            buffer = fs.readFileSync(local);
            type = local.endsWith('.svg') ? 'image/svg+xml' : local.match(/\.jpe?g$/i) ? 'image/jpeg' : 'image/png';
        }
        return `data:${type};base64,${buffer.toString('base64')}`;
    } catch (error) {
        console.warn('Report logo not loaded:', error.message);
        return null;
    }
}

// ---------- model ----------
function fmtDate(d) {
    if (!d) return '—';
    const date = new Date(d);
    if (Number.isNaN(date.getTime())) return '—';
    const two = (n) => String(n).padStart(2, '0');
    return `${two(date.getDate())}/${two(date.getMonth() + 1)}/${date.getFullYear()} ${two(date.getHours())}:${two(date.getMinutes())}`;
}

function rangeText(r) {
    if (r.normalText) return r.normalText;
    const has = (v) => v !== null && v !== undefined && v !== '';
    if (has(r.min) && has(r.max)) return `${r.min} – ${r.max}`;
    if (has(r.min)) return `≥ ${r.min}`;
    if (has(r.max)) return `≤ ${r.max}`;
    return '';
}

/**
 * @param order  decorated order (patientInfo) with results
 * @param lab    lab document
 * @param rows   rows from routes/lab/results buildRows (value, unit, min, max, flag, category)
 */
async function buildHtml({ order, lab, rows, approvedBy, baseUrl }) {
    const info = order.patientInfo || {};
    const approved = order.results?.entryStatus === 'approved';
    const approvedAt = order.results?.approvedAt || null;
    const groups = [];
    for (const r of rows) {
        const category = r.category || 'General';
        let g = groups.find((x) => x.category === category);
        if (!g) groups.push(g = { category, rows: [] });
        g.rows.push({
            name: r.testName, nameAr: r.testNameAr && r.testNameAr !== r.testName ? r.testNameAr : '',
            value: r.value, unit: r.unit || '', range: rangeText(r), flag: r.flag === 'high' || r.flag === 'low' ? r.flag : '',
        });
    }
    const qr = approved && baseUrl
        ? await QRCode.toDataURL(verifyUrl(baseUrl, String(order._id), approvedAt), { margin: 0, width: 240, errorCorrectionLevel: 'M' })
        : null;
    return ejs.renderFile(TEMPLATE, {
        fontFaces: fontFaces(),
        accent: '#FF5A00',
        approved,
        lab: {
            name: lab.name || '', nameAr: lab.nameAr || '',
            address: [lab.address, lab.city].filter(Boolean).join(' - '), phone: lab.phone || '', email: lab.email || '',
            licenseNumber: lab.licenseNumber || '', accreditation: lab.accreditation || '',
        },
        logo: await logoDataUrl(lab.logo),
        patient: {
            name: info.name || '', no: info.patientNo || null, phone: info.phone || '',
            gender: info.gender === 'female' ? 'Female' : info.gender === 'male' ? 'Male' : '',
            age: Number.isInteger(info.age) ? `${info.age} y` : '',
        },
        order: {
            code: order.qrCode || '', doctor: order.walkIn?.doctor || '', sample: SAMPLE[order.walkIn?.sampleType] || '',
            collectedAt: fmtDate(order.createdAt), reportedAt: fmtDate(approvedAt || new Date()),
        },
        groups,
        comment: order.results?.comment || '',
        approvedBy: approvedBy || '',
        qr,
    });
}

// ---------- Chromium ----------
let browserPromise = null;
let idleTimer = null;
let active = 0;
const waiting = [];
const MAX_PARALLEL = 2;

function chromePath() {
    const fromEnv = process.env.PUPPETEER_EXECUTABLE_PATH || process.env.CHROME_PATH;
    if (fromEnv && fs.existsSync(fromEnv)) return fromEnv;
    return CHROME_CANDIDATES.find((p) => fs.existsSync(p)) || null;
}

function isAvailable() {
    return Boolean(chromePath());
}

async function getBrowser() {
    if (browserPromise) {
        const b = await browserPromise.catch(() => null);
        if (b && b.connected) return b;
        browserPromise = null;
    }
    const executablePath = chromePath();
    if (!executablePath) throw new PdfUnavailableError('No Chromium found for PDF reports (set PUPPETEER_EXECUTABLE_PATH)');
    const puppeteer = require('puppeteer-core');
    browserPromise = puppeteer.launch({
        executablePath,
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--font-render-hinting=none', '--disable-gpu'],
    });
    const browser = await browserPromise;
    browser.on('disconnected', () => { browserPromise = null; });
    return browser;
}

// Close the browser after a quiet minute so it does not hold memory.
function scheduleIdleClose() {
    clearTimeout(idleTimer);
    idleTimer = setTimeout(async () => {
        if (active > 0 || !browserPromise) return;
        const b = await browserPromise.catch(() => null);
        browserPromise = null;
        if (b) await b.close().catch(() => {});
    }, 60000);
    if (idleTimer.unref) idleTimer.unref();
}

async function withSlot(fn) {
    if (active >= MAX_PARALLEL) await new Promise((resolve) => waiting.push(resolve));
    active += 1;
    try {
        return await fn();
    } finally {
        active -= 1;
        const next = waiting.shift();
        if (next) next();
        scheduleIdleClose();
    }
}

async function renderPdf(html, { footerLeft = '' } = {}) {
    return withSlot(async () => {
        const browser = await getBrowser();
        const page = await browser.newPage();
        try {
            await page.setJavaScriptEnabled(false);
            await page.setContent(html, { waitUntil: 'load', timeout: 20000 });
            await page.evaluateHandle('document.fonts.ready').catch(() => {});
            const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
            const pdf = await page.pdf({
                format: 'A4',
                printBackground: true,
                preferCSSPageSize: true,
                displayHeaderFooter: true,
                headerTemplate: '<span></span>',
                footerTemplate: `<div style="width:100%;font-size:7.5px;color:#6b7280;padding:0 13mm;display:flex;justify-content:space-between;font-family:sans-serif">
                    <span>${esc(footerLeft)}</span><span>Page <span class="pageNumber"></span> / <span class="totalPages"></span></span></div>`,
            });
            return Buffer.from(pdf);
        } finally {
            await page.close().catch(() => {});
        }
    });
}

// Closes the shared browser (tests, shutdown).
async function closeBrowser() {
    clearTimeout(idleTimer);
    const b = browserPromise ? await browserPromise.catch(() => null) : null;
    browserPromise = null;
    if (b) await b.close().catch(() => {});
}

async function buildReportPdf(args) {
    const html = await buildHtml(args);
    const footer = [args.lab?.name, args.order?.qrCode].filter(Boolean).join(' · ');
    return renderPdf(html, { footerLeft: footer });
}

module.exports = {
    buildHtml,
    buildReportPdf,
    renderPdf,
    closeBrowser,
    isAvailable,
    verifyUrl,
    checkSignature,
    PdfUnavailableError,
};
