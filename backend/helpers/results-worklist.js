// One row of the results worklist (web "Results" page): where an order stands
// in result entry. pending = nothing entered, draft = some values saved,
// approved = sent to the patient.
const { decorateOrderWithPatientInfo } = require('./order-patient-info');
const { receiptCode } = require('../services/receiptLinkService');

function worklistRow(order) {
    const o = decorateOrderWithPatientInfo(order);
    const info = o.patientInfo || {};
    const values = o.results?.values || [];
    const filled = values.filter((v) => String(v.value || '').trim()).length;
    const entry = o.results?.entryStatus || 'none';
    // approved = sent to the patient; draft = some values saved; pending = nothing yet
    const state = entry === 'approved' || (o.status === 'completed' && (o.results?.reportUrl || values.length)) ? 'approved'
        : (entry === 'draft' || filled > 0) ? 'draft' : 'pending';
    return {
        id: String(o._id), orderNo: receiptCode(o),
        name: info.name || '', patientNo: info.patientNo || null, phone: info.phone || '',
        tests: (o.tests || []).map((t) => t.testName), total: (o.tests || []).length, filled,
        urgent: o.urgency === 'urgent' || o.urgency === 'emergency', state,
        hasReport: Boolean(o.results?.reportUrl), createdAt: o.createdAt, approvedAt: o.results?.approvedAt || null,
    };
}

module.exports = { worklistRow };
