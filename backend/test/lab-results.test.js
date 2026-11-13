const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const mongoose = require('mongoose');

const path = require('node:path');

// The real FCM service needs a firebase key file that isn't in the repo.
const fcmPath = path.join(__dirname, '../services/fcmService.js');
const fcmService = { sendToUser: async () => {} };
require.cache[fcmPath] = { id: fcmPath, filename: fcmPath, loaded: true, exports: fcmService };

const Order = require('../models/Order');
const User = require('../models/User');
const { pickRange, classify } = require('../helpers/result-ranges');

const labId = new mongoose.Types.ObjectId();
const cbcId = new mongoose.Types.ObjectId();
const vitId = new mongoose.Types.ObjectId();

const lab = {
    _id: labId,
    name: 'Test Lab',
    tests: [
        { _id: cbcId, name: 'Hemoglobin', code: 'HB', unit: 'g/dL', normalText: '', ranges: [
            { gender: 'Female', ageFrom: 0, ageTo: 120, ageUnit: 'Y', min: 12, max: 15.5 },
            { gender: 'Male', ageFrom: 0, ageTo: 120, ageUnit: 'Y', min: 13.5, max: 17.5 },
        ] },
        { _id: vitId, name: 'Vitamin D', code: 'VITD', unit: 'ng/mL', normalText: '', ranges: [] },
    ],
};

function makeOrder(status = 'at_lab') {
    const order = new Order({
        patientId: new mongoose.Types.ObjectId(),
        labId,
        status,
        location: { address: 'x', coordinates: { latitude: 33, longitude: 44 } },
        tests: [
            { testId: cbcId, testName: 'Hemoglobin', testCode: 'HB', price: 10000 },
            { testId: vitId, testName: 'Vitamin D', testCode: 'VITD', price: 40000 },
        ],
        pricing: { subtotal: 50000, total: 50000 },
    });
    order.beneficiary = { isForOtherPerson: true, name: 'Sara', gender: 'female', birthDate: new Date('1995-01-01') };
    order.save = async function save() { return this; };
    return order;
}

async function startServer(t, order) {
    t.mock.method(Order, 'findById', () => ({ populate: async () => order }));
    t.mock.method(fcmService, 'sendToUser', async () => {});
    const router = require('../routes/lab/results');
    const app = express();
    app.use(express.json());
    app.use((req, res, next) => { req.lab = lab; req.user = { _id: new mongoose.Types.ObjectId() }; next(); });
    app.use(router);
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise((resolve) => server.close(resolve)));
    const base = `http://127.0.0.1:${server.address().port}`;
    const call = (path, method = 'GET', body) => fetch(base + path, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: body ? JSON.stringify(body) : undefined,
    }).then(async (r) => ({ status: r.status, json: await r.json() }));
    call.base = base;
    return call;
}

test('ranges follow gender and values are flagged', () => {
    const female = pickRange(lab.tests[0].ranges, { gender: 'female', age: 30 });
    assert.equal(female.min, 12);
    const male = pickRange(lab.tests[0].ranges, { gender: 'male', age: 30 });
    assert.equal(male.min, 13.5);
    assert.equal(classify('11', 12, 15.5), 'low');
    assert.equal(classify('16', 12, 15.5), 'high');
    assert.equal(classify('13', 12, 15.5), 'normal');
    assert.equal(classify('Negative', 12, 15.5), '');
    assert.equal(classify('20', null, null), '');
});

test('draft save stores values with flags and the patient range', async (t) => {
    const order = makeOrder();
    const call = await startServer(t, order);
    const res = await call(`/api/orders/${order._id}/results`, 'PUT', {
        values: [{ testId: String(cbcId), value: '11.2' }],
    });
    assert.equal(res.status, 200);
    const hb = res.json.data.rows.find((r) => r.testName === 'Hemoglobin');
    assert.equal(hb.flag, 'low');
    assert.equal(hb.min, 12);
    assert.equal(hb.unit, 'g/dL');
    assert.equal(hb.ranges.length, 2, 'editor gets every range group');
    assert.equal(order.results.entryStatus, 'draft');
    assert.equal(order.status, 'at_lab');
});

test('approve refuses missing values, then completes and keeps the values', async (t) => {
    const order = makeOrder();
    const call = await startServer(t, order);
    const missing = await call(`/api/orders/${order._id}/results/approve`, 'POST', {
        values: [{ testId: String(cbcId), value: '14' }],
    });
    assert.equal(missing.status, 400);
    assert.deepEqual(missing.json.missing, ['Vitamin D']);

    const ok = await call(`/api/orders/${order._id}/results/approve`, 'POST', {
        values: [{ testId: String(cbcId), value: '14' }, { testId: String(vitId), value: '25' }],
        reportUrl: 'https://files.example/report.pdf',
    });
    assert.equal(ok.status, 200);
    assert.equal(order.status, 'completed');
    assert.equal(order.results.reportUrl, 'https://files.example/report.pdf');
    assert.equal(order.results.entryStatus, 'approved');
    assert.equal(order.results.values.length, 2);
    assert.equal(fcmService.sendToUser.mock.callCount(), 1);
});

test('results cannot be entered before the sample reaches the lab', async (t) => {
    const order = makeOrder('sample_collected');
    const call = await startServer(t, order);
    const res = await call(`/api/orders/${order._id}/results`, 'PUT', { values: [] });
    assert.equal(res.status, 400);
});

test('orders from another lab are refused', async (t) => {
    const order = makeOrder();
    order.labId = new mongoose.Types.ObjectId();
    const call = await startServer(t, order);
    const res = await call(`/api/orders/${order._id}/results`);
    assert.equal(res.status, 403);
});

test('approving without a file builds the report on the server and uploads it', async (t) => {
    const r2Service = require('../services/r2Service');
    const reportPdf = require('../services/reportPdfService');
    const order = makeOrder();
    const call = await startServer(t, order);
    let built = null;
    t.mock.method(reportPdf, 'buildReportPdf', async (args) => { built = args; return Buffer.from('%PDF-1.7 test'); });
    t.mock.method(r2Service, 'uploadBuffer', async (buf, folder, name, opts) => ({ url: `/${folder}/${name}`, contentType: opts.contentType }));
    const res = await call(`/api/orders/${order._id}/results/approve`, 'POST', {
        values: [{ testId: String(cbcId), value: '14' }, { testId: String(vitId), value: '25' }],
    });
    assert.equal(res.status, 200);
    assert.equal(built.order.results.entryStatus, 'approved', 'the report is built as approved');
    assert.equal(built.rows.length, 2);
    assert.match(order.results.reportUrl, /^\/uploads\/results\/report-.*\.pdf$/);
    assert.equal(order.status, 'completed');
});

test('without a PDF engine nothing is approved and the caller is told to fall back', async (t) => {
    const reportPdf = require('../services/reportPdfService');
    const order = makeOrder();
    const call = await startServer(t, order);
    let saved = 0;
    order.save = async function save() { saved += 1; return this; };
    t.mock.method(reportPdf, 'buildReportPdf', async () => { throw new reportPdf.PdfUnavailableError('none'); });
    const res = await call(`/api/orders/${order._id}/results/approve`, 'POST', {
        values: [{ testId: String(cbcId), value: '14' }, { testId: String(vitId), value: '25' }],
    });
    assert.equal(res.status, 503);
    assert.equal(res.json.code, 'pdfUnavailable');
    assert.equal(saved, 0);
    assert.equal(order.status, 'at_lab');
});

test('the report endpoint returns a real PDF (needs Chromium)', { skip: !require('../services/reportPdfService').isAvailable() && 'no Chromium here' }, async (t) => {
    const order = makeOrder('completed');
    order.results = { values: [{ testId: cbcId, testName: 'Hemoglobin', value: '11.2', unit: 'g/dL', min: 12, max: 15.5, flag: 'low' },
        { testId: vitId, testName: 'Vitamin D', value: '45', unit: 'ng/mL' }], entryStatus: 'approved', approvedAt: new Date() };
    const call = await startServer(t, order);
    t.mock.method(User, 'findById', () => ({ select: async () => ({ name: 'Dr. Ahmed' }) }));
    t.after(() => require('../services/reportPdfService').closeBrowser());
    const base = call.base;
    const res = await fetch(`${base}/api/orders/${order._id}/report.pdf`);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('content-type'), 'application/pdf');
    const buf = Buffer.from(await res.arrayBuffer());
    assert.equal(buf.subarray(0, 5).toString(), '%PDF-');
});
