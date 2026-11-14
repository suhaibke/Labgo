// The payment receipt printed at reception (80 mm roll, browser print preview):
// order number V0001 as a Code 128 barcode, a QR that opens the result once
// approved, and an URGENT band. Same content as the lab app's receipt.
const QRCode = require('qrcode');
const bwipjs = require('bwip-js');
const receipt = require('./receiptLinkService');

const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
const money = (n) => Math.round(Number(n) || 0).toLocaleString('en-US');

function ageOf(birthDate) {
    if (!birthDate) return '';
    const ms = Date.now() - new Date(birthDate).getTime();
    if (!(ms > 0)) return '';
    const days = Math.floor(ms / 86400000);
    if (days < 31) return `${days}D`;
    if (days < 365) return `${Math.floor(days / 30.4)}M`;
    return `${Math.floor(days / 365.25)}Y`;
}

const COPY = {
    ar: { patient: 'المريض', ageGender: 'العمر / الجنس', doctor: 'الطبيب', company: 'الجهة', order: 'رقم الطلب', date: 'التاريخ', total: 'الإجمالي', discount: 'الخصم', paid: 'تم الدفع', later: 'الدفع لاحقاً — معلق', scan: 'امسح لعرض النتيجة عند جاهزيتها', urgent: 'عاجل', male: 'ذكر', female: 'أنثى', thanks: 'شكراً لاختياركم' },
    en: { patient: 'Patient', ageGender: 'Age / Gender', doctor: 'Doctor', company: 'Company', order: 'Order No.', date: 'Date', total: 'TOTAL', discount: 'Discount', paid: 'Paid', later: 'Pay later — pending', scan: 'Scan to view the result when ready', urgent: 'URGENT', male: 'Male', female: 'Female', thanks: 'Thank you' },
    ku: { patient: 'نەخۆش', ageGender: 'تەمەن / ڕەگەز', doctor: 'پزیشک', company: 'لایەن', order: 'ژمارەی داواکاری', date: 'بەروار', total: 'کۆی گشتی', discount: 'داشکاندن', paid: 'پارەدراوە', later: 'دواتر پارەبدە — چاوەڕوانە', scan: 'سکان بکە بۆ بینینی ئەنجام کاتێک ئامادەبوو', urgent: 'بەپەلە', male: 'نێر', female: 'مێ', thanks: 'سوپاس' },
    tr: { patient: 'Hasta', ageGender: 'Yaş / Cinsiyet', doctor: 'Doktor', company: 'Kurum', order: 'Sipariş No.', date: 'Tarih', total: 'TOPLAM', discount: 'İndirim', paid: 'Ödendi', later: 'Sonra ödenecek — bekliyor', scan: 'Sonuç hazır olunca görmek için tarayın', urgent: 'ACİL', male: 'Erkek', female: 'Kadın', thanks: 'Teşekkürler' },
};

async function receiptHtml({ order, lab, baseUrl, lang = 'ar', autoPrint = true }) {
    const t = COPY[lang] || COPY.ar;
    const rtl = ['ar', 'ku'].includes(lang);
    const code = receipt.receiptCode(order);
    const person = order.beneficiary?.isForOtherPerson ? order.beneficiary : (order.patientId || {});
    const gender = person.gender === 'male' ? t.male : person.gender === 'female' ? t.female : '';
    const age = ageOf(person.birthDate);
    const qr = await QRCode.toString(receipt.resultLink(baseUrl, String(order._id)), { type: 'svg', margin: 0, errorCorrectionLevel: 'M' });
    const bar = bwipjs.toSVG({ bcid: 'code128', text: code || String(order._id).slice(-8), height: 11, scale: 2, includetext: false, paddingwidth: 0, paddingheight: 0 });
    const when = new Date(order.createdAt || Date.now());
    const date = `${when.getFullYear()}/${String(when.getMonth() + 1).padStart(2, '0')}/${String(when.getDate()).padStart(2, '0')} ${String(when.getHours()).padStart(2, '0')}:${String(when.getMinutes()).padStart(2, '0')}`;
    const paid = order.payment?.status === 'paid' || order.paymentCollected?.collected;
    const rows = (order.tests || []).map((x) => `<tr><td>${esc(x.testName)}</td><td class="n">${money(x.price)}</td></tr>`).join('');
    const line = (a, b, cls = '') => (b ? `<div class="kv ${cls}"><span>${esc(a)}</span><b>${b}</b></div>` : '');
    return `<!doctype html><html lang="${esc(lang)}" dir="${rtl ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><title>${esc(code)}</title>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@400;600;700&family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
<style>
@page { size: 80mm auto; margin: 4mm; }
* { box-sizing: border-box; }
body { margin: 0 auto; width: 72mm; font-family: "Inter", "IBM Plex Sans Arabic", sans-serif; color: #000; font-size: 11px; line-height: 1.45; }
.c { text-align: center; } .mut { color: #333; font-size: 10px; }
h1 { margin: 2px 0 0; font-size: 15px; text-align: center; }
.logo { display: block; margin: 0 auto; height: 34px; }
.urgent { margin: 8px 0 2px; padding: 5px 0; background: #000; color: #fff; text-align: center; font-weight: 700; font-size: 15px; letter-spacing: 1px; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
hr { border: 0; border-top: 1px dashed #000; margin: 8px 0; }
.kv { display: flex; justify-content: space-between; gap: 8px; } .kv span { color: #333; } .kv b { font-weight: 600; text-align: end; }
.kv.big b { font-size: 15px; font-weight: 700; letter-spacing: .5px; }
table { width: 100%; border-collapse: collapse; } td { padding: 2px 0; vertical-align: top; } td.n { text-align: end; white-space: nowrap; font-variant-numeric: tabular-nums; }
.total { display: flex; justify-content: space-between; font-size: 14px; font-weight: 700; }
.pay { display: inline-block; margin-top: 4px; padding: 1px 8px; border: 1px solid #000; font-weight: 600; font-size: 10px; }
.codes { text-align: center; margin-top: 10px; }
.bar svg { width: 60mm; height: 14mm; } .code { font-weight: 700; font-size: 14px; letter-spacing: 2px; margin-top: 2px; }
.qr svg { width: 26mm; height: 26mm; margin-top: 8px; }
@media screen { body { padding: 16px 0; } }
</style></head><body>
${lab.logo ? `<img class="logo" src="${esc(lab.logo)}" alt="">` : ''}
<h1>${esc(lab.name)}</h1>
${lab.phone ? `<div class="c mut" dir="ltr">${esc(lab.phone)}</div>` : ''}
${lab.address ? `<div class="c mut">${esc([lab.address, lab.city].filter(Boolean).join(' - '))}</div>` : ''}
${order.urgency === 'urgent' ? `<div class="urgent">⚡ ${esc(t.urgent)}${lang === 'en' ? '' : ' • URGENT'}</div>` : ''}
<hr>
${line(t.order, `<span dir="ltr">${esc(code)}</span>`, 'big')}
${line(t.patient, esc(person.name || ''))}
${line(t.ageGender, esc([age, gender].filter(Boolean).join(' • ')))}
${line(t.doctor, esc(order.walkIn?.doctor || ''))}
${line(t.company, esc(order.walkIn?.company || ''))}
${line(t.date, `<span dir="ltr">${date}</span>`)}
<hr>
<table>${rows}</table>
<hr>
${order.pricing?.discount ? line(t.discount, `<span dir="ltr">-${money(order.pricing.discount)}</span>`) : ''}
<div class="total"><span>${esc(t.total)}</span><span dir="ltr">${money(order.pricing?.total)} IQD</span></div>
<div class="c"><span class="pay">${esc(paid ? t.paid : t.later)}</span></div>
<div class="codes">
  <div class="bar">${bar}</div><div class="code" dir="ltr">${esc(code)}</div>
  <div class="qr">${qr}</div><div class="mut">${esc(t.scan)}</div>
</div>
<hr><div class="c" style="font-weight:700">${esc(t.thanks)} • LabGo</div>
${autoPrint ? '<script>window.addEventListener("load",function(){setTimeout(function(){window.print()},300)})</script>' : ''}
</body></html>`;
}

module.exports = { receiptHtml, ageOf };
