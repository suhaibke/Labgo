// Supplies orders: list, create, delete, and a printable copy for the supplier.
const express = require('express');
const mongoose = require('mongoose');
const SupplyOrder = require('../../models/SupplyOrder');
const Counter = require('../../models/Counter');

const router = express.Router();

const clip = (v, n) => String(v ?? '').trim().slice(0, n);

function langOf(req) {
    const currentLang = req.cookies?.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
    return { currentLang, direction: ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr' };
}

function view(o) {
    return {
        id: String(o._id), no: o.no, supplier: o.supplier, supplierPhone: o.supplierPhone, neededBy: o.neededBy,
        notes: o.notes, items: (o.items || []).map((i) => ({ name: i.name, qty: i.qty, unit: i.unit })),
        date: o.createdAt, createdAt: o.createdAt,
    };
}

// Validates and cleans a posted order; returns { order } or { error, code }.
function parse(body) {
    const b = body || {};
    const items = (Array.isArray(b.items) ? b.items : [])
        .map((i) => ({ name: clip(i?.name, 160), qty: clip(i?.qty, 20), unit: clip(i?.unit, 20) }))
        .filter((i) => i.name)
        .slice(0, 100);
    if (!items.length) return { error: 'Add at least one item', code: 'items' };
    const neededBy = clip(b.neededBy, 20);
    if (neededBy && !/^\d{4}-\d{2}-\d{2}$/.test(neededBy)) return { error: 'Invalid date', code: 'neededBy' };
    return {
        order: {
            supplier: clip(b.supplier, 160), supplierPhone: clip(b.supplierPhone, 40), neededBy,
            notes: clip(b.notes, 1000), items,
        },
    };
}

async function listFor(labId) {
    const list = await SupplyOrder.find({ labId }).sort({ no: -1 }).limit(200).lean();
    return list.map(view);
}

router.get('/supplies', async (req, res) => {
    try {
        res.render('dashboard/lab-supplies', {
            lab: req.lab, user: req.user, title: req.lab.name, ...langOf(req), activeSection: 'supplies',
            dataJson: JSON.stringify({ orders: await listFor(req.lab._id) }).replace(/</g, '\\u003c'),
        });
    } catch (error) {
        console.error('Supplies page error:', error);
        res.status(500).render('error', { message: 'Error loading supplies', error: null });
    }
});

router.get('/api/supplies', async (req, res) => {
    try {
        res.json({ success: true, data: { orders: await listFor(req.lab._id) } });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Error loading orders' });
    }
});

router.post('/api/supplies', async (req, res) => {
    try {
        const { order, error, code } = parse(req.body);
        if (error) return res.status(400).json({ success: false, message: error, code });
        const no = await Counter.next(`supply:${req.lab._id}`, 100);
        const saved = await SupplyOrder.create({ ...order, labId: req.lab._id, no, createdBy: req.user?._id || null });
        res.status(201).json({ success: true, data: view(saved) });
    } catch (error) {
        console.error('Supply order create error:', error);
        res.status(500).json({ success: false, message: 'Error saving the order' });
    }
});

router.delete('/api/supplies/:id', async (req, res) => {
    try {
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) return res.status(404).json({ success: false });
        const r = await SupplyOrder.deleteOne({ _id: req.params.id, labId: req.lab._id });
        if (!r.deletedCount) return res.status(404).json({ success: false, message: 'Not found' });
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false });
    }
});

module.exports = router;
module.exports.parse = parse;
module.exports.view = view;
