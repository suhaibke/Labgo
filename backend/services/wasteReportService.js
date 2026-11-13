// PDF report of a medical waste pickup request (lab dashboard and admin panel).
const ejs = require('ejs');
const path = require('path');
const reportPdf = require('./reportPdfService');

const TYPE_LABELS = {
    biohazard: 'نفايات خطرة بيولوجياً · Biohazard',
    sharps: 'أدوات حادة · Sharps',
    chemical: 'نفايات كيميائية · Chemical',
    general: 'نفايات عامة · General',
};

function fmt(d) {
    if (!d) return '—';
    const x = new Date(d);
    const two = (n) => String(n).padStart(2, '0');
    return `${two(x.getDate())}/${two(x.getMonth() + 1)}/${x.getFullYear()}`;
}

async function wasteReportHtml(item, lab) {
    return ejs.renderFile(path.join(__dirname, '../views/reports/waste-request.ejs'), {
        item,
        lab: { name: lab?.name || '', address: lab?.address || '', city: lab?.city || '', phone: lab?.phone || '', logo: lab?.logo || '' },
        typeLabel: TYPE_LABELS[item.type] || item.type,
        created: fmt(item.createdAt),
        pickup: fmt(item.pickupDate),
        fontFaces: reportPdf.fontFaces ? reportPdf.fontFaces() : '',
    });
}

async function wasteReportPdf(item, lab) {
    const html = await wasteReportHtml(item, lab);
    return reportPdf.renderPdf(html, { footerLeft: `${lab?.name || ''} · #${item.requestNo || ''}`, showPlatform: true });
}

module.exports = { wasteReportHtml, wasteReportPdf, TYPE_LABELS };
