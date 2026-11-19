// Results index for archiving: one Excel row per order with every detail of
// the patient, the order, the results and where the report file is kept.
// Readable on its own, without LabGo, next to the archived files
// (uploads/results/L101/2026-11/V0006-4fK9xQ2m.pdf).
const XLSX = require('xlsx');
const Order = require('../models/Order');
const Lab = require('../models/Lab');
const User = require('../models/User');
const { decorateOrderWithPatientInfo } = require('../helpers/order-patient-info');
const receipt = require('./receiptLinkService');

const STATUS = {
    pending: 'Pending', quoted: 'Quoted', confirmed: 'Confirmed', nurse_assigned: 'Nurse assigned',
    sample_collected: 'Sample collected', at_lab: 'At the lab', completed: 'Completed', cancelled: 'Cancelled',
};
const PAY = { pending: 'Unpaid', partial: 'Partly paid', paid: 'Paid', refunded: 'Refunded' };

const date = (d) => {
    const x = d ? new Date(d) : null;
    return x && !Number.isNaN(x.getTime()) ? x : '';
};

function paidOf(o) {
    if (typeof o.payment?.paidAmount === 'number') return o.payment.paidAmount;
    return o.payment?.status === 'paid' ? (o.pricing?.total || 0) : 0;
}

function row(order, lab, approvers, baseUrl) {
    const o = decorateOrderWithPatientInfo(order);
    const p = o.patientInfo || {};
    const account = o.patientId && typeof o.patientId === 'object' ? o.patientId : {};
    const values = o.results?.values || [];
    const total = o.pricing?.total || 0;
    const paid = paidOf(o);
    return {
        'Lab no.': Lab.code(lab),
        'Lab': lab.name || '',
        'Receipt no.': receipt.receiptCode(o),
        'Order code': o.qrCode || '',
        'Result link': o.resultCode && baseUrl ? receipt.shortLink(baseUrl, o.resultCode) : '',
        'Order date': date(o.createdAt),
        'Order type': o.orderType === 'walk_in' ? 'At the lab' : 'Home collection',
        'Status': STATUS[o.status] || o.status || '',

        'Patient name': p.name || '',
        'Patient ID': p.patientNo ? `#${p.patientNo}` : '',
        'Phone': p.phone || '',
        'Gender': p.gender === 'female' ? 'Female' : p.gender === 'male' ? 'Male' : '',
        'Birth date': date(p.birthDate),
        'Age (years)': Number.isInteger(p.age) ? p.age : '',
        'For someone else': p.isBeneficiary ? 'Yes' : 'No',
        'Relationship': p.isBeneficiary ? (o.beneficiary?.relationship || '') : '',
        'Account holder': p.isBeneficiary ? (account.name || '') : '',
        'Account phone': p.isBeneficiary ? (account.phone || '') : '',
        'Email': account.email || '',
        'Address': o.location?.address || '',

        'Doctor': o.walkIn?.doctor || '',
        'Company': o.walkIn?.company || '',
        'Sample': o.walkIn?.sampleType || '',
        'Urgency': o.urgency || '',
        'Tests': (o.tests || []).map((t) => t.testName).join(', '),
        'Results': values.filter((v) => v.value)
            .map((v) => `${v.testName}: ${v.value}${v.unit ? ` ${v.unit}` : ''}${v.flag === 'high' ? ' (H)' : v.flag === 'low' ? ' (L)' : ''}`)
            .join(' | '),
        'High / low': values.filter((v) => v.flag === 'high' || v.flag === 'low').map((v) => v.testName).join(', '),
        'Result comment': o.results?.comment || '',
        'Lab notes': o.notes?.labNotes || '',
        'Result state': o.results?.entryStatus === 'approved' ? 'Approved' : o.results?.entryStatus === 'draft' ? 'Draft' : 'Not entered',
        'Approved at': date(o.results?.approvedAt),
        'Approved by': approvers.get(String(o.results?.approvedBy || '')) || '',

        'Subtotal': o.pricing?.subtotal ?? total,
        'Discount': o.pricing?.discount || 0,
        'Total': total,
        'Paid': paid,
        'Due': Math.max(0, total - paid),
        'Payment': PAY[o.payment?.status] || '',

        'Report file': o.results?.reportUrl || '',
    };
}

/**
 * Builds the workbook for one lab (or every lab when [labId] is 'all').
 * [from] / [to] limit the orders by date (optional).
 */
async function buildIndex({ labId, from, to, baseUrl = '' }) {
    const labs = labId === 'all'
        ? await Lab.find().select('name labNo city phone email address createdAt').sort({ labNo: 1 }).lean()
        : await Lab.find({ _id: labId }).select('name labNo city phone email address createdAt').lean();
    if (!labs.length) return null;
    const byId = new Map(labs.map((l) => [String(l._id), l]));

    const query = { labId: { $in: labs.map((l) => l._id) } };
    if (from || to) {
        query.createdAt = {};
        if (from) query.createdAt.$gte = new Date(from);
        if (to) query.createdAt.$lt = new Date(new Date(to).getTime() + 86400000);
    }
    const orders = await Order.find(query)
        .populate('patientId', 'name phone email gender birthDate patientNo')
        .sort({ labId: 1, createdAt: 1 })
        .lean();

    const approverIds = [...new Set(orders.map((o) => String(o.results?.approvedBy || '')).filter(Boolean))];
    const approvers = new Map((await User.find({ _id: { $in: approverIds } }).select('name').lean()).map((u) => [String(u._id), u.name || '']));

    const rows = orders.map((o) => row(o, byId.get(String(o.labId)) || {}, approvers, baseUrl));
    const wb = XLSX.utils.book_new();
    const header = Object.keys(row({}, labs[0], approvers, baseUrl));
    const sheet = XLSX.utils.json_to_sheet(rows, { header, cellDates: true, dateNF: 'yyyy-mm-dd hh:mm' });
    sheet['!cols'] = header.map((k) => ({ wch: k === 'Results' || k === 'Report file' ? 48 : Math.max(10, k.length + 2) }));
    sheet['!autofilter'] = { ref: sheet['!ref'] };
    XLSX.utils.book_append_sheet(wb, sheet, 'Results');

    const labSheet = XLSX.utils.json_to_sheet(labs.map((l) => ({
        'Lab no.': Lab.code(l), 'Lab': l.name || '', 'City': l.city || '', 'Phone': l.phone || '',
        'Email': l.email || '', 'Address': l.address || '', 'Joined': date(l.createdAt),
        'Orders in this file': orders.filter((o) => String(o.labId) === String(l._id)).length,
        'Files folder': l.labNo ? `uploads/results/L${l.labNo}/` : '',
    })), { cellDates: true, dateNF: 'yyyy-mm-dd' });
    XLSX.utils.book_append_sheet(wb, labSheet, 'Labs');

    const name = labs.length === 1 ? `${Lab.code(labs[0]) || 'lab'}-results-index` : 'all-labs-results-index';
    return { buffer: XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' }), filename: `${name}.xlsx`, count: orders.length };
}

module.exports = { buildIndex };
