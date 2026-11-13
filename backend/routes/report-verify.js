// Public page opened from the QR code on a result report. It confirms the
// report was issued by the lab and when, without showing any results.
const express = require('express');
const mongoose = require('mongoose');
const Order = require('../models/Order');
const { checkSignature } = require('../services/reportPdfService');
const { getOrderPatientInfo } = require('../helpers/order-patient-info');

const router = express.Router();

// "Sara Ali Hussein" -> "Sara A. H."
function maskName(name) {
    const parts = String(name || '').trim().split(/\s+/).filter(Boolean);
    if (!parts.length) return '';
    return [parts[0], ...parts.slice(1).map((p) => `${p.charAt(0)}.`)].join(' ');
}

router.get('/verify-report/:id', async (req, res) => {
    let view = { valid: false };
    try {
        if (mongoose.Types.ObjectId.isValid(req.params.id)) {
            const order = await Order.findById(req.params.id)
                .select('qrCode labId tests results beneficiary patientId createdAt')
                .populate('labId', 'name city')
                .populate('patientId', 'name');
            const approvedAt = order?.results?.approvedAt;
            if (order && order.results?.entryStatus === 'approved' && checkSignature(String(order._id), approvedAt, req.query.s)) {
                view = {
                    valid: true,
                    lab: [order.labId?.name, order.labId?.city].filter(Boolean).join(' - '),
                    code: order.qrCode,
                    patient: maskName(getOrderPatientInfo(order.toObject()).name),
                    tests: (order.tests || []).length,
                    approvedAt: new Date(approvedAt).toISOString().replace('T', ' ').slice(0, 16) + ' UTC',
                };
            }
        }
    } catch (error) {
        console.error('Report verification error:', error);
    }
    res.set('Cache-Control', 'no-store');
    res.set('X-Robots-Tag', 'noindex');
    res.status(view.valid ? 200 : 404).render('reports/verify', view);
});

module.exports = router;
module.exports.maskName = maskName;
