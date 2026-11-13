// Public page behind the QR code on a lab receipt.
const express = require('express');
const mongoose = require('mongoose');
const Order = require('../models/Order');
const receipt = require('../services/receiptLinkService');

const router = express.Router();

router.get('/r/o/:id', async (req, res) => {
    res.set('Cache-Control', 'no-store');
    res.set('X-Robots-Tag', 'noindex');
    let state = 'invalid';
    let info = {};
    try {
        if (mongoose.Types.ObjectId.isValid(req.params.id) && receipt.checkKey(req.params.id, req.query.k)) {
            const order = await Order.findById(req.params.id).select('receiptNo qrCode labId results status').populate('labId', 'name phone');
            if (order) {
                info = { code: receipt.receiptCode(order), lab: order.labId?.name || '', phone: order.labId?.phone || '' };
                const url = order.results?.reportUrl;
                if (order.results?.entryStatus === 'approved' && url) return res.redirect(302, url);
                state = 'waiting';
            }
        }
    } catch (error) {
        console.error('Receipt result page error:', error);
    }
    const ready = state === 'waiting';
    res.status(ready ? 200 : 404).send(`<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>LabGo</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#EDEDED;font-family:-apple-system,Segoe UI,Tahoma,sans-serif;color:#111;padding:16px}
.c{width:min(420px,100%);background:#F7F7F7;border-radius:28px;padding:28px 22px;text-align:center}.i{width:72px;height:72px;border-radius:50%;display:grid;place-items:center;margin:0 auto 12px;font-size:34px;background:#FFF0E6;color:#FF5A00}
h1{font-size:21px;margin:0 0 6px}p{color:#6E6E73;line-height:1.7;margin:0}.code{display:inline-block;margin-top:10px;background:#FFF0E6;color:#FF5A00;font-weight:800;border-radius:999px;padding:4px 14px;direction:ltr}</style></head>
<body><main class="c">${ready
        ? `<div class="i">⏳</div><h1>النتيجة غير جاهزة بعد</h1><p>Your result is not ready yet.<br>امسح الرمز مرة أخرى لاحقاً، أو تواصل مع ${escapeHtml(info.lab)}${info.phone ? ` <span dir="ltr">${escapeHtml(info.phone)}</span>` : ''}.</p><span class="code">${escapeHtml(info.code)}</span>`
        : '<div class="i">!</div><h1>رابط غير صالح</h1><p>This link is not valid.</p>'}</main></body></html>`);
});

function escapeHtml(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

module.exports = router;
