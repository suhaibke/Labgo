const assert = require('node:assert/strict');
const http = require('node:http');
const path = require('node:path');
const test = require('node:test');
const express = require('express');
const mongoose = require('mongoose');

const fcmPath = path.join(__dirname, '../services/fcmService.js');
const fcm = { sendToUser: async () => {} };
require.cache[fcmPath] = { id: fcmPath, filename: fcmPath, loaded: true, exports: fcm };

const ExternalTransfer = require('../models/ExternalTransfer');
const Lab = require('../models/Lab');
const Order = require('../models/Order');
const r2Service = require('../services/r2Service');
const transferLabel = require('../services/transferLabelService');

function makeTransfer(extra = {}) {
    const t = new ExternalTransfer({
        labId: new mongoose.Types.ObjectId(), sampleCode: 'LG-2026-4820', patientName: 'Sara Ali Hussein',
        tests: [{ testName: 'Vitamin D' }], externalLab: { name: 'Al-Hayat Lab' }, status: 'sent', sentAt: new Date(), ...extra,
    });
    t.save = async function save() { return this; };
    return t;
}

async function serve(t, app) {
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise((resolve) => server.close(resolve)));
    return `http://127.0.0.1:${server.address().port}`;
}

function publicApp() {
    const app = express();
    app.set('view engine', 'ejs');
    app.set('views', path.join(__dirname, '../views'));
    app.use(require('../routes/transfer-upload'));
    return app;
}

test('the label carries a real QR (upload link) and a Code 128 barcode', async () => {
    const transfer = makeTransfer();
    const data = await transferLabel.labelData({ transfer, lab: { name: 'LabGo Mosul' }, baseUrl: 'https://labgo.iq' });
    assert.match(data.uploadUrl, new RegExp(`^https://labgo.iq/r/t/${transfer._id}\\?k=[a-f0-9]{20}$`));
    assert.match(data.qrSvg, /<svg/);
    assert.match(data.barcodeSvg, /<svg/);
    assert.equal(data.fromLab, 'LabGo Mosul');
    assert.equal(data.toLab, 'Al-Hayat Lab');
    const html = await transferLabel.labelHtml({ transfer, lab: { name: 'LabGo Mosul' }, baseUrl: 'https://labgo.iq', lang: 'ar' });
    assert.match(html, /ملصق الشحن/);
    assert.match(html, /border: 2px dashed #FF5A00/);
});

test('the QR page needs the right key and masks the patient name', async (t) => {
    const transfer = makeTransfer();
    t.mock.method(ExternalTransfer, 'findById', async () => transfer);
    t.mock.method(Lab, 'findById', () => ({ select: async () => ({ name: 'LabGo Mosul' }) }));
    const base = await serve(t, publicApp());
    let res = await fetch(`${base}/r/t/${transfer._id}?k=wrongwrongwrongwrong`);
    assert.equal(res.status, 404);
    res = await fetch(`${base}/r/t/${transfer._id}?k=${transferLabel.key(transfer)}`);
    assert.equal(res.status, 200);
    const html = await res.text();
    assert.match(html, /Sara A\. H\./);
    assert.doesNotMatch(html, /Sara Ali Hussein/);
});

test('the receiving lab uploads once; the order is not completed until the lab reviews it', async (t) => {
    const transfer = makeTransfer({ orderId: new mongoose.Types.ObjectId() });
    t.mock.method(ExternalTransfer, 'findById', async () => transfer);
    t.mock.method(Lab, 'findById', () => ({ select: async () => ({ name: 'LabGo Mosul' }) }));
    const uploads = [];
    t.mock.method(r2Service, 'uploadBuffer', async (buf, folder, name, opts) => { uploads.push(opts.contentType); return { url: `/${folder}/${name}` }; });
    const orderFind = t.mock.method(Order, 'findById', async () => null);
    const base = await serve(t, publicApp());
    const url = `${base}/r/t/${transfer._id}?k=${transferLabel.key(transfer)}`;

    const bad = new FormData();
    bad.append('resultFile', new Blob(['x'], { type: 'text/plain' }), 'r.txt');
    let res = await fetch(url, { method: 'POST', body: bad });
    assert.equal(res.status, 400, 'only PDF or images');
    assert.equal(transfer.status, 'sent');

    const form = new FormData();
    form.append('uploaderName', 'Al-Hayat Lab');
    form.append('resultFile', new Blob(['%PDF-1.7'], { type: 'application/pdf' }), 'result.pdf');
    res = await fetch(url, { method: 'POST', body: form });
    assert.equal(res.status, 200);
    assert.equal(transfer.status, 'completed');
    assert.equal(transfer.resultSource, 'external_link');
    assert.equal(transfer.externalUpload.uploaderName, 'Al-Hayat Lab');
    assert.match(transfer.resultFileUrl, /^\/uploads\/results\/ext-upload-/);
    assert.equal(orderFind.mock.callCount(), 0, 'patient order untouched');

    res = await fetch(url, { method: 'POST', body: form });
    assert.equal(uploads.length, 1, 'a received result cannot be replaced from the link');
});

test('the lab sends a reviewed external result on to the patient', async (t) => {
    const order = new Order({ patientId: new mongoose.Types.ObjectId(), labId: new mongoose.Types.ObjectId(), status: 'at_lab', qrCode: 'LG-1',
        location: { address: 'x', coordinates: { latitude: 0, longitude: 0 } }, tests: [], pricing: { subtotal: 0, total: 0 }, payment: { amount: 0 } });
    order.save = async function save() { return this; };
    const transfer = makeTransfer({ orderId: order._id, status: 'completed', resultFileUrl: '/uploads/results/x.pdf', resultSource: 'external_link' });
    transfer.labId = order.labId;
    t.mock.method(ExternalTransfer, 'findById', async () => transfer);
    t.mock.method(Order, 'findById', async () => order);
    const sent = t.mock.method(fcm, 'sendToUser', async () => {});
    const app = express();
    app.use(express.json());
    app.use((req, res, next) => { req.lab = { _id: order.labId }; req.user = { _id: new mongoose.Types.ObjectId() }; next(); });
    app.use(require('../routes/lab/external-transfers'));
    const base = await serve(t, app);
    const res = await fetch(`${base}/api/external-transfers/${transfer._id}/forward`, { method: 'POST' });
    assert.equal(res.status, 200);
    assert.equal(order.status, 'completed');
    assert.equal(order.results.reportUrl, '/uploads/results/x.pdf');
    assert.ok(transfer.forwardedAt);
    assert.equal(sent.mock.callCount(), 1);
});
