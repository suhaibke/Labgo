// Public result page behind the short link (/r/V0001-k7Qm2x) sent by WhatsApp / SMS
// and the QR code on the receipt and the report.
//
// - App installed: iOS opens the LabGo app from the Universal Link (see
//   /.well-known/apple-app-site-association) and this page never loads; Android
//   tries the app first (intent link) and comes back here with ?web=1 if it isn't there.
// - No app: the result is shown in the browser, with the PDF and an invitation
//   to download the app.
const express = require('express');
const mongoose = require('mongoose');
const Order = require('../models/Order');
const receipt = require('../services/receiptLinkService');
const r2Service = require('../services/r2Service');
const path = require('path');
const storeLinks = require('../config/storeLinks');

const router = express.Router();

const FIELDS = 'receiptNo qrCode resultCode labId patientId beneficiary results status createdAt';
const POPULATE = [
    { path: 'labId', select: 'name phone logo' },
    { path: 'patientId', select: 'name' },
];
const ANDROID_PACKAGE = 'com.labgo.app';

function isApproved(order) {
    return order?.results?.entryStatus === 'approved';
}

// What the page and the app show: never more than the printed report has.
// "LG-MWNGRNM9-A61EKC" -> "LG-A61EKC"; receipt numbers (V0006) stay as they are.
function shortCode(code) {
    const parts = String(code || '').split('-').filter(Boolean);
    return parts.length > 2 ? `${parts[0]}-${parts[parts.length - 1]}` : String(code || '');
}

const ICONS = {
    // test tube with a liquid level: the sample being worked on
    tube: '<svg viewBox="0 0 24 24" width="30" height="30" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M14.5 2v17.5a2.5 2.5 0 0 1-5 0V2"/><path d="M8.5 2h7"/><path d="M9.5 13h5"/></svg>',
    phone: '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6A19.79 19.79 0 0 1 2.12 4.18 2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.9.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"/></svg>',
    file: '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M12 12v6"/><path d="m15 15-3 3-3-3"/></svg>',
};

function view(order) {
    const approved = isApproved(order);
    const name = order.beneficiary?.isForOtherPerson ? order.beneficiary?.name : order.patientId?.name;
    return {
        code: shortCode(receipt.receiptCode(order)),
        // 0 = waiting for the sample, 1 = being analysed, 2 = ready
        stage: approved ? 2 : ['sample_collected', 'at_lab', 'completed'].includes(order.status) ? 1 : 0,
        lab: { name: order.labId?.name || '', phone: order.labId?.phone || '', logo: order.labId?.logo || '' },
        ready: approved,
        patient: approved ? (name || '') : '',
        date: (order.results?.approvedAt || order.createdAt || null),
        reportUrl: approved ? (order.results?.reportUrl || '') : '',
        results: approved
            ? (order.results?.values || []).filter((v) => String(v.value || '').trim()).map((v) => ({
                test: v.testName || '',
                value: v.value || '',
                unit: v.unit || '',
                range: v.normalText || (v.min != null && v.max != null ? `${v.min} - ${v.max}` : ''),
                flag: v.flag || '',
            }))
            : [],
        comment: approved ? (order.results?.comment || '') : '',
    };
}

async function byCode(raw) {
    const code = receipt.normalizeCode(raw);
    if (!code) return { code: null, order: null };
    const order = await Order.findOne({ resultCode: code }).select(FIELDS).populate(POPULATE);
    return { code, order };
}

// QR on older printed receipts: long signed link.
router.get('/r/o/:id', async (req, res) => {
    let order = null;
    try {
        if (mongoose.Types.ObjectId.isValid(req.params.id) && receipt.checkKey(req.params.id, req.query.k)) {
            order = await Order.findById(req.params.id).select(FIELDS).populate(POPULATE);
        }
    } catch (error) {
        console.error('Receipt result page error:', error);
    }
    if (order?.resultCode) return res.redirect(302, `/r/${order.resultCode}`);
    page(req, res, order, null);
});

// The result for the patient app (opened from the same short link).
router.get('/r/:code/data', async (req, res, next) => {
    try {
        const { code, order } = await byCode(req.params.code);
        if (!code) return next();
        res.set('Cache-Control', 'no-store');
        if (!order) return res.status(404).json({ success: false, message: 'This link is not valid' });
        res.json({ success: true, data: view(order) });
    } catch (error) {
        console.error('Result data error:', error);
        res.status(500).json({ success: false });
    }
});

// Short link sent to the patient by WhatsApp / SMS and printed as a QR code.
router.get('/r/:code', async (req, res, next) => {
    let found = { code: null, order: null };
    try {
        found = await byCode(req.params.code);
        if (!found.code) return next();
    } catch (error) {
        console.error('Short result link error:', error);
    }
    // Result complete: straight to the PDF report. Otherwise the "in progress" page.
    if (isApproved(found.order) && found.order.results?.reportUrl) {
        return sendReport(res, found.order.results.reportUrl, found.code);
    }
    page(req, res, found.order, found.code);
});

// The report is served under the short link itself, so the storage path
// (uploads/results/<lab>/...) is never shown to the patient. Files kept
// elsewhere (an external URL) are still redirected to.
async function sendReport(res, url, code) {
    if (!String(url).startsWith('/uploads/')) return res.redirect(302, url);
    try {
        const file = await r2Service.getFileStream(url);
        if (!file) return res.status(404).send('Report not found');
        const ext = path.extname(url).toLowerCase() || '.pdf';
        res.set('Content-Type', file.contentType || 'application/pdf');
        if (file.contentLength) res.set('Content-Length', String(file.contentLength));
        res.set('Content-Disposition', `inline; filename="LabGo-${String(code).replace(/[^\w-]/g, '')}${ext}"`);
        res.set('Cache-Control', 'private, no-store');
        res.set('X-Robots-Tag', 'noindex');
        file.stream.on('error', () => res.destroy());
        return file.stream.pipe(res);
    } catch (error) {
        console.error('Short link report error:', error.message);
        return res.redirect(302, url);
    }
}

function page(req, res, order, code) {
    res.set('Cache-Control', 'no-store');
    res.set('X-Robots-Tag', 'noindex');
    const v = order ? view(order) : null;
    const webOnly = Boolean(req.query.web);
    const self = code ? `${req.protocol}://${req.get('host')}/r/${code}` : '';
    const intent = code
        ? `intent://result/${encodeURIComponent(code)}#Intent;scheme=labgo;package=${ANDROID_PACKAGE};S.browser_fallback_url=${encodeURIComponent(`${self}?web=1`)};end`
        : '';
    const flagText = { high: 'مرتفع', low: 'منخفض', normal: 'طبيعي' };
    const when = v?.date ? new Date(v.date) : null;
    const date = when ? `${when.getFullYear()}/${String(when.getMonth() + 1).padStart(2, '0')}/${String(when.getDate()).padStart(2, '0')}` : '';

    const rows = (v?.results || []).map((r) => `<tr>
      <td class="t">${esc(r.test)}</td>
      <td class="v ${esc(r.flag)}"><span dir="ltr">${esc(r.value)}${r.unit ? ` <small>${esc(r.unit)}</small>` : ''}</span>${r.flag ? `<em class="f ${esc(r.flag)}">${flagText[r.flag] || ''}</em>` : ''}</td>
      <td class="r" dir="ltr">${esc(r.range)}</td></tr>`).join('');

    let body;
    if (!v) {
        body = `<section class="card c"><div class="ic bad">!</div><h1>رابط غير صالح</h1><p>This link is not valid.</p></section>`;
    } else if (!v.ready) {
        const steps = ['استلام العينة', 'قيد التحليل', 'النتيجة جاهزة'];
        body = `<section class="card c" aria-labelledby="t">
          <div class="ic"><span class="ring" aria-hidden="true"></span>${ICONS.tube}</div>
          <h1 id="t">نتيجتك قيد العمل</h1>
          <p>${v.stage === 0 ? 'سيبدأ التحليل فور وصول العينة إلى المختبر.' : 'المختبر يحلل عينتك الآن.'} ستصلك رسالة عند الجاهزية، وهذا الرابط نفسه سيفتح التقرير مباشرة.</p>
          <p class="en" lang="en" dir="ltr">Your result is in progress. This link opens the report as soon as it is ready.</p>
          <ol class="stepper" aria-label="مراحل النتيجة">
            ${steps.map((label, i) => `<li class="${i < v.stage ? 'done' : i === v.stage ? 'now' : ''}"${i === v.stage ? ' aria-current="step"' : ''}><span class="dot" aria-hidden="true"></span>${label}</li>`).join('')}
          </ol>
          <div class="meta"><span>رقم الطلب</span><b dir="ltr">${esc(v.code)}</b></div>
          ${v.lab.phone ? `<a class="btn ghost call" href="tel:${esc(v.lab.phone)}">${ICONS.phone}<span>اتصل بالمختبر</span></a>` : ''}
        </section>`;
    } else {
        body = `<section class="card">
          <div class="who"><div><div class="mut">المريض · Patient</div><b>${esc(v.patient)}</b></div>
          <div class="end"><div class="mut">رقم الطلب</div><b dir="ltr">${esc(v.code)}</b>${date ? `<div class="mut" dir="ltr">${date}</div>` : ''}</div></div>
          ${rows ? `<table><thead><tr><th>التحليل</th><th>النتيجة</th><th>المعدل الطبيعي</th></tr></thead><tbody>${rows}</tbody></table>` : '<p class="mut c">التقرير مرفق بصيغة PDF.</p>'}
          ${v.comment ? `<p class="note">${esc(v.comment)}</p>` : ''}
          <div class="acts">
            ${v.reportUrl ? `<a class="btn main" href="${esc(self || v.reportUrl)}">${ICONS.file}<span>تحميل التقرير PDF</span></a>` : ''}
            ${code ? `<a class="btn ghost" id="openApp" href="${esc(intent)}">فتح في تطبيق LabGo</a>` : ''}
          </div></section>`;
    }

    const invite = v ? `<section class="card app">
        <img src="/images/logo.png" alt="LabGo" class="applogo">
        <div><h2>حمّل تطبيق LabGo</h2><p>استلم نتائجك فور جاهزيتها، احفظ تقاريرك في مكان واحد، واحجز تحاليلك وسحب الدم من البيت.</p>
        <div class="stores"><a id="ios" class="store" href="${esc(storeLinks.ios)}">App Store</a><a id="android" class="store" href="${esc(storeLinks.android)}">Google Play</a></div></div>
      </section>` : '';

    res.status(v ? 200 : 404).send(`<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">
<title>${v ? `${esc(v.lab.name)} · ${v.ready ? 'نتيجة التحليل' : 'النتيجة'}` : 'LabGo'}</title>
<meta name="apple-itunes-app" content="app-id=${esc((storeLinks.ios.match(/id(\d+)/) || [])[1] || '')}${code ? `, app-argument=${esc(self)}` : ''}">
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@400;600;700&display=swap" rel="stylesheet">
<style>
:root{--o:#FF5A00;--o-text:#B93C00;--o-soft:#FFF0E6;--ok:#15803D;--ok-soft:#EAF9EE;--ink:#16181D;--mut:#5B6170;--line:#E5E7EB;--bg:#EFEFF1;--card:#fff;--chip:#F3F4F6;color-scheme:light dark}
@media (prefers-color-scheme:dark){:root{--o-text:#FF9A5C;--o-soft:#3A2416;--ok:#4ADE80;--ok-soft:#14301F;--ink:#F2F2F4;--mut:#A3A7B3;--line:#2E3036;--bg:#0E0F12;--card:#1A1B1F;--chip:#25272C}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font-family:"IBM Plex Sans Arabic",-apple-system,"Segoe UI",Tahoma,sans-serif;padding:16px;line-height:1.6}
.wrap{max-width:560px;margin:0 auto;display:grid;gap:12px}
header{display:flex;align-items:center;gap:12px;padding:6px 4px}header img{width:46px;height:46px;border-radius:12px;object-fit:contain;background:#fff}
header b{font-size:18px;display:block}header a{color:var(--mut);font-size:13px;text-decoration:none}
.card{background:var(--card);border-radius:22px;padding:18px;box-shadow:0 1px 2px rgba(0,0,0,.04)}
.c{text-align:center}.ic{position:relative;width:72px;height:72px;border-radius:50%;display:grid;place-items:center;margin:4px auto 12px;font-size:30px;background:var(--o-soft);color:var(--o-text)}.ic.bad{font-weight:800}
.ring{position:absolute;inset:-4px;border-radius:50%;border:3px solid transparent;border-top-color:var(--o);animation:spin 1.6s linear infinite}
.en{font-size:12px;margin-top:4px}
.stepper{list-style:none;display:flex;margin:18px 0 6px;padding:0}.stepper li{flex:1;position:relative;font-size:12.5px;color:var(--mut);display:grid;justify-items:center;gap:6px}
.stepper li::before{content:"";position:absolute;top:7px;inset-inline-start:50%;width:100%;height:2px;background:var(--line);z-index:0}.stepper li:last-child::before{display:none}
.stepper .dot{width:16px;height:16px;border-radius:50%;background:var(--card);border:2px solid var(--line);position:relative;z-index:1}
.stepper .done{color:var(--ok)}.stepper .done .dot{background:var(--ok);border-color:var(--ok)}.stepper .done::before{background:var(--ok)}
.stepper .now{color:var(--o-text);font-weight:700}.stepper .now .dot{border-color:var(--o);box-shadow:0 0 0 4px var(--o-soft)}
.meta{display:flex;justify-content:center;gap:8px;align-items:baseline;margin-top:14px;font-size:13px;color:var(--mut)}.meta b{color:var(--ink);font-size:15px;letter-spacing:.5px}
.call{display:flex;align-items:center;justify-content:center;gap:8px;margin-top:14px;min-height:44px}
h1{font-size:20px;margin:0 0 6px}p{margin:0;color:var(--mut)}.mut{color:var(--mut);font-size:12px}

.who{display:flex;justify-content:space-between;gap:10px;margin-bottom:12px}.who b{font-size:17px}.end{text-align:left}
table{width:100%;border-collapse:collapse;font-size:14px}th{font-size:12px;color:var(--mut);font-weight:600;text-align:right;padding:8px 6px;border-bottom:1px solid var(--line)}
td{padding:10px 6px;border-bottom:1px solid var(--line);vertical-align:top}td.t{font-weight:600}td.r{color:var(--mut);font-size:12px;white-space:nowrap}
td.v span{font-weight:700;white-space:nowrap}td.v small{font-weight:400;color:var(--mut)}td.v.high span{color:#DC2626}td.v.low span{color:#2563EB}
.f{display:block;font-style:normal;font-size:11px;font-weight:600}.f.high{color:#DC2626}.f.low{color:#2563EB}.f.normal{color:#16A34A}
.note{margin-top:12px;background:#F5F6F8;border-radius:12px;padding:10px;color:var(--ink);font-size:13px}
.acts{display:grid;gap:8px;margin-top:16px}.btn{display:flex;align-items:center;justify-content:center;gap:8px;min-height:48px;border-radius:14px;padding:12px;font-weight:700;text-decoration:none;font-size:15px}
.main{background:var(--o);color:#fff}.ghost{background:var(--o-soft);color:var(--o-text)}
a:focus-visible{outline:3px solid var(--o);outline-offset:2px}
.app{display:flex;gap:14px;align-items:flex-start}.applogo{width:56px;height:56px;border-radius:14px;background:#fff;border:1px solid var(--line);object-fit:contain;padding:6px}
.app h2{margin:0 0 4px;font-size:16px}.app p{font-size:13px}.stores{display:flex;gap:8px;margin-top:10px;flex-wrap:wrap}
.store{display:inline-flex;align-items:center;min-height:44px;background:var(--ink);color:var(--card);text-decoration:none;border-radius:12px;padding:0 16px;font-size:14px;font-weight:600}
.hide{display:none}
@keyframes spin{to{transform:rotate(360deg)}}
@media (prefers-reduced-motion:reduce){.ring{animation:none;border-color:var(--o-soft);border-top-color:var(--o)}}
footer{text-align:center;color:var(--mut);font-size:12px;padding:6px}
</style></head><body><div class="wrap">
${v ? `<header>${v.lab.logo ? `<img src="${esc(v.lab.logo)}" alt="">` : ''}<div><b>${esc(v.lab.name)}</b>${v.lab.phone ? `<a dir="ltr" href="tel:${esc(v.lab.phone)}" aria-label="هاتف المختبر ${esc(v.lab.phone)}">${esc(v.lab.phone)}</a>` : ''}</div></header>` : ''}
${body}
${invite}
<footer>LabGo · labgo-iq.com</footer>
</div>
<script>
(function(){
  var ua = navigator.userAgent;
  var isIos = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var isAndroid = /Android/i.test(ua);
  function hide(id){ var e = document.getElementById(id); if (e) e.classList.add('hide'); }
  if (isIos) { hide('android'); hide('openApp'); }   // iOS opens the app from the link itself
  if (isAndroid) hide('ios');
  if (!isIos && !isAndroid) hide('openApp');
  // Android: open the app when it is installed; otherwise the intent comes back with ?web=1.
  ${code && !webOnly && v && !v.ready ? `if (isAndroid) window.location.href = ${JSON.stringify(intent)};` : ''}
})();
</script></body></html>`);
}

function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

module.exports = router;
