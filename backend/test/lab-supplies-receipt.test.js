const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const mongoose = require('mongoose');
const SupplyOrder = require('../models/SupplyOrder');
const Counter = require('../models/Counter');
const supplies = require('../routes/lab/supplies');
const { receiptHtml, ageOf } = require('../services/receiptPrintService');
const perms = require('../helpers/lab-permissions');

const labId = new mongoose.Types.ObjectId();

async function start(t) {
    const app = express();
    app.use(express.json());
    app.use((req, res, next) => { req.lab = { _id: labId, name: 'Lab' }; req.user = { _id: new mongoose.Types.ObjectId() }; next(); });
    app.use(supplies);
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise((resolve) => server.close(resolve)));
    return `http://127.0.0.1:${server.address().port}`;
}

test('a supplies order needs at least one named item and a valid date', () => {
    assert.equal(supplies.parse({ items: [] }).code, 'items');
    assert.equal(supplies.parse({ items: [{ name: '  ' }] }).code, 'items');
    assert.equal(supplies.parse({ items: [{ name: 'Gloves' }], neededBy: '20/11/2026' }).code, 'neededBy');
    const { order } = supplies.parse({ supplier: ' Rafidain ', items: [{ name: 'Gloves', qty: 5 }, { name: '' }], neededBy: '2026-11-20' });
    assert.equal(order.supplier, 'Rafidain');
    assert.deepEqual(order.items, [{ name: 'Gloves', qty: '5', unit: '' }]);
});

test('saving an order numbers it per lab and returns the saved copy', async (t) => {
    const created = [];
    t.mock.method(SupplyOrder, 'create', async (doc) => { created.push(doc); return { ...doc, _id: new mongoose.Types.ObjectId(), createdAt: new Date() }; });
    let counterName;
    t.mock.method(Counter, 'next', async (name) => { counterName = name; return 101; });
    const base = await start(t);
    const res = await fetch(`${base}/api/supplies`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ items: [{ name: 'EDTA tubes', qty: '10', unit: 'pack' }] }) });
    assert.equal(res.status, 201);
    const body = await res.json();
    assert.equal(body.data.no, 101);
    assert.equal(counterName, `supply:${labId}`);
    assert.equal(String(created[0].labId), String(labId));
    const bad = await fetch(`${base}/api/supplies`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ items: [] }) });
    assert.equal(bad.status, 400);
});

test('deleting only touches this lab\'s orders', async (t) => {
    let filter;
    t.mock.method(SupplyOrder, 'deleteOne', async (f) => { filter = f; return { deletedCount: 1 }; });
    const base = await start(t);
    const id = new mongoose.Types.ObjectId();
    assert.equal((await fetch(`${base}/api/supplies/${id}`, { method: 'DELETE' })).status, 200);
    assert.equal(String(filter.labId), String(labId));
    assert.equal((await fetch(`${base}/api/supplies/not-an-id`, { method: 'DELETE' })).status, 404);
});

test('the receipt shows the order number, urgent band, barcode and result QR', async () => {
    const html = await receiptHtml({
        order: { _id: new mongoose.Types.ObjectId(), receiptNo: 7, urgency: 'urgent', createdAt: new Date(), patientId: { name: 'Omar', gender: 'male', birthDate: new Date(Date.now() - 31.5 * 365.25 * 864e5) },
            walkIn: { doctor: 'Dr. Sara' }, tests: [{ testName: 'CBC', price: 15000 }], pricing: { total: 15000 }, payment: { status: 'pending' } },
        lab: { name: 'LabGo Mosul' }, baseUrl: 'https://x.test', lang: 'en', autoPrint: false,
    });
    assert.match(html, /V0007/);
    assert.match(html, /class="urgent"/);
    assert.match(html, /<svg[\s\S]*<\/svg>/);
    assert.match(html, /Pay later/);
    assert.match(html, /31Y/);
    assert.doesNotMatch(html, /window\.print/);
});

test('routine orders have no urgent band', async () => {
    const html = await receiptHtml({ order: { _id: new mongoose.Types.ObjectId(), receiptNo: 1, urgency: 'routine', tests: [], pricing: { total: 0 }, payment: { status: 'paid' } }, lab: { name: 'L' }, baseUrl: 'https://x.test', lang: 'ar' });
    assert.doesNotMatch(html, /class="urgent"/);
    assert.match(html, /window\.print/);
});

test('ages print in days, months or years', () => {
    assert.equal(ageOf(new Date(Date.now() - 10 * 864e5)), '10D');
    assert.equal(ageOf(new Date(Date.now() - 100 * 864e5)), '3M');
    assert.equal(ageOf(null), '');
});

test('new pages: market and support for all staff, supplies for store or finance', () => {
    assert.equal(perms.canAccess('/market', [], false), true);
    assert.equal(perms.canAccess('/support', [], false), true);
    assert.equal(perms.canAccess('/supplies', ['patients'], false), false);
    assert.equal(perms.canAccess('/supplies', ['store'], false), true);
    assert.equal(perms.canAccess('/api/supplies', ['finance'], false), true);
    assert.equal(perms.canAccess('/orders/abc/receipt', ['patients'], false), true);
});
