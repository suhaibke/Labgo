const assert = require('node:assert/strict');
const http = require('node:http');
const path = require('node:path');
const test = require('node:test');
const express = require('express');
const mongoose = require('mongoose');

const fcmPath = path.join(__dirname, '../services/fcmService.js');
require.cache[fcmPath] = { id: fcmPath, filename: fcmPath, loaded: true, exports: { sendToUser: async () => {} } };

const ExternalTransfer = require('../models/ExternalTransfer');
const Order = require('../models/Order');
const Lab = require('../models/Lab');
const Notification = require('../models/Notification');
const User = require('../models/User');
const r2Service = require('../services/r2Service');
const reportPdf = require('../services/reportPdfService');
const labTransfers = require('../services/labTransferService');

const sendingLabId = new mongoose.Types.ObjectId();
const receivingLab = {
    _id: new mongoose.Types.ObjectId(), name: 'Al-Hayat Lab', status: 'Active',
    tests: [
        { _id: new mongoose.Types.ObjectId(), name: 'Vitamin D', nameAr: 'فيتامين د', code: 'VITD', price: 40000, priceB2B: 25000, unit: 'ng/mL', ranges: [{ gender: 'Both', ageFrom: 0, ageTo: 120, ageUnit: 'Y', min: 30, max: 100 }] },
        { _id: new mongoose.Types.ObjectId(), name: 'Ferritin', code: 'FER', price: 15000, priceB2B: 0, ranges: [] },
    ],
};

test('the price comes from the receiving lab B2B prices (normal price when none)', () => {
    const q = labTransfers.quote(receivingLab, ['فيتامين د', 'Ferritin', 'Unknown test']);
    assert.equal(q.total, 25000 + 15000);
    assert.deepEqual(q.missing, ['Unknown test']);
});

test('a typed price wins over the quote; the receiving lab is remembered', () => {
    const fields = { tests: [{ testName: 'Vitamin D' }] };
    labTransfers.applyTargetAndPrice(fields, {}, receivingLab);
    assert.equal(fields.price, 25000);
    assert.equal(fields.priceSource, 'b2b');
    assert.equal(String(fields.toLabId), String(receivingLab._id));
    const typed = { tests: [{ testName: 'Vitamin D' }] };
    labTransfers.applyTargetAndPrice(typed, { price: '30,000' }, receivingLab);
    assert.equal(typed.price, 30000);
    assert.equal(typed.priceSource, 'manual');
});

function transfer(extra = {}) {
    const t = new ExternalTransfer({ labId: sendingLabId, toLabId: receivingLab._id, sampleCode: 'LG-2026-4820', patientName: 'Sara Ali',
        patientGender: 'female', patientAge: 31, tests: [{ testName: 'Vitamin D' }], externalLab: { name: 'Al-Hayat Lab' }, status: 'sent', sentAt: new Date(), ...extra });
    t.save = async function save() { return this; };
    return t;
}

async function receivingServer(t) {
    const app = express();
    app.use(express.json());
    app.use((req, res, next) => { req.lab = receivingLab; req.user = { _id: new mongoose.Types.ObjectId(), name: 'Dr. Noor' }; next(); });
    app.use(require('../routes/lab/transfers-in'));
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise((resolve) => server.close(resolve)));
    const base = `http://127.0.0.1:${server.address().port}`;
    return (p, method = 'GET', body) => fetch(base + p, { method, headers: { 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined })
        .then(async (r) => ({ status: r.status, json: await r.json() }));
}

function captureNotifications(t) {
    const sent = [];
    t.mock.method(Lab, 'findById', (id) => ({ select: async () => ({ _id: id, ownerId: new mongoose.Types.ObjectId(), name: String(id) === String(sendingLabId) ? 'LabGo Mosul' : 'Al-Hayat Lab' }) }));
    t.mock.method(User, 'find', () => ({ select: async () => [] }));
    t.mock.method(Notification, 'insertMany', async (docs) => { sent.push(...docs); return docs; });
    return sent;
}

test('receiving by barcode notifies the sending lab once', async (t) => {
    const tr = transfer();
    t.mock.method(ExternalTransfer, 'findOne', async () => tr);
    const sent = captureNotifications(t);
    const call = await receivingServer(t);
    let res = await call('/api/transfers/incoming/receive', 'POST', { code: 'lg-2026-4820' });
    assert.equal(res.status, 200);
    assert.equal(res.json.data.status, 'received');
    assert.ok(tr.receivedAt);
    assert.equal(sent.length, 1);
    assert.equal(sent[0].data.type, 'transfer_received');
    res = await call('/api/transfers/incoming/receive', 'POST', { code: 'LG-2026-4820' });
    assert.equal(sent.length, 1, 'no second notification');
});

test('approved results go to the sending lab: report, draft values on its order, notification', async (t) => {
    const order = new Order({ patientId: new mongoose.Types.ObjectId(), labId: sendingLabId, status: 'at_lab', qrCode: 'LG-2026-4820',
        location: { address: 'x', coordinates: { latitude: 0, longitude: 0 } }, tests: [{ testId: new mongoose.Types.ObjectId(), testName: 'Vitamin D', testCode: 'V', price: 1 }],
        pricing: { subtotal: 1, total: 1 }, payment: { amount: 1 } });
    order.save = async function save() { return this; };
    const tr = transfer({ orderId: order._id, receivedAt: new Date() });
    t.mock.method(ExternalTransfer, 'findOne', async () => tr);
    t.mock.method(Order, 'findById', async () => order);
    t.mock.method(reportPdf, 'buildReportPdf', async () => Buffer.from('%PDF'));
    t.mock.method(r2Service, 'uploadBuffer', async (b, folder, name) => ({ url: `/${folder}/${name}` }));
    const sent = captureNotifications(t);
    const call = await receivingServer(t);

    let res = await call(`/api/transfers/incoming/${tr._id}/results`, 'PUT', { values: [{ testName: 'Vitamin D', value: '22' }] });
    assert.equal(res.status, 200);
    assert.equal(res.json.data.rows[0].flag, 'low', 'the receiving lab ranges apply');

    res = await call(`/api/transfers/incoming/${tr._id}/results/approve`, 'POST', { values: [{ testName: 'Vitamin D', value: '22' }] });
    assert.equal(res.status, 200);
    assert.equal(tr.status, 'completed');
    assert.equal(tr.resultSource, 'receiving_lab');
    assert.match(tr.resultFileUrl, /b2b-report-/);
    assert.equal(order.results.values[0].value, '22');
    assert.equal(order.results.entryStatus, 'draft', 'the sending lab still reviews and approves');
    assert.equal(order.status, 'at_lab');
    assert.equal(sent.at(-1).data.type, 'transfer_result');
});

test('another lab cannot open a sample that was not sent to it', async (t) => {
    t.mock.method(ExternalTransfer, 'findOne', async () => null);
    const call = await receivingServer(t);
    const res = await call(`/api/transfers/incoming/${new mongoose.Types.ObjectId()}/results`);
    assert.equal(res.status, 404);
});
