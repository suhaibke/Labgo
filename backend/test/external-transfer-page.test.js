const assert = require('node:assert/strict');
const http = require('node:http');
const path = require('node:path');
const test = require('node:test');
const ejs = require('ejs');
const express = require('express');
const Order = require('../models/Order');
const ExternalTransfer = require('../models/ExternalTransfer');

const languages = ['ar', 'en', 'ku', 'tr'];
const requiredKeys = [
    'common.age',
    'common.years',
    'common.notAvailable',
    'navigation.externalTransfers',
    'externalTransfers.title',
    'externalTransfers.newTransfer',
    'externalTransfers.selectSample',
    'externalTransfers.labName',
    'externalTransfers.uploadResult',
    'externalTransfers.manualEntry',
    'externalTransfers.patientName',
];

function readKey(source, dottedKey) {
    return dottedKey.split('.').reduce((value, key) => value?.[key], source);
}

test('every dashboard language contains transfer and demographic labels', () => {
    for (const language of languages) {
        const dictionary = require(`../i18n/languages/${language}.json`);
        for (const key of requiredKeys) {
            assert.equal(
                typeof readKey(dictionary, key),
                'string',
                `${language} is missing ${key}`
            );
        }
    }
});

test('external transfer router exposes the notebook, creation and result endpoints', () => {
    const router = require('../routes/lab/external-transfers');
    const endpoints = router.stack
        .filter(layer => layer.route)
        .flatMap(layer => Object.keys(layer.route.methods).map(method => `${method.toUpperCase()} ${layer.route.path}`));

    assert.ok(endpoints.includes('GET /external-transfers'));
    assert.ok(endpoints.includes('POST /api/external-transfers'));
    assert.ok(endpoints.includes('POST /api/external-transfers/:id/result'));
    assert.ok(endpoints.includes('DELETE /api/external-transfers/:id'));
});

test('creation endpoint persists a manual transfer with no linked order', async t => {
    const router = require('../routes/lab/external-transfers');
    let created = null;
    t.mock.method(ExternalTransfer, 'create', async (fields) => {
        created = fields;
        return { _id: 'transfer-1', ...fields };
    });

    const app = express();
    app.use(express.json());
    app.use((req, res, next) => {
        req.lab = { _id: 'lab-1' };
        req.user = { _id: 'lab-owner-1' };
        next();
    });
    app.use(router);
    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise(resolve => server.close(resolve)));

    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/external-transfers`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            labName: 'Reference Lab',
            referenceNumber: 'REF-1',
            patientName: 'Walk-in Patient',
            patientPhone: '07701234567',
            patientGender: 'male',
            patientAge: '40',
            testsDescription: 'CBC',
        }),
    });
    const body = await response.json();

    assert.equal(response.status, 201);
    assert.equal(body.success, true);
    assert.equal(created.labId, 'lab-1');
    assert.equal(created.orderId, undefined);
    assert.equal(created.patientName, 'Walk-in Patient');
    assert.equal(created.patientAge, 40);
    assert.equal(created.externalLab.name, 'Reference Lab');
});

test('creation endpoint rejects a manual transfer with no patient name', async t => {
    const router = require('../routes/lab/external-transfers');
    t.mock.method(ExternalTransfer, 'create', async (fields) => ({ _id: 'transfer-x', ...fields }));

    const app = express();
    app.use(express.json());
    app.use((req, res, next) => {
        req.lab = { _id: 'lab-1' };
        req.user = { _id: 'lab-owner-1' };
        next();
    });
    app.use(router);
    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise(resolve => server.close(resolve)));

    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/external-transfers`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ labName: 'Reference Lab' }),
    });
    const body = await response.json();

    assert.equal(response.status, 400);
    assert.equal(body.success, false);
});

test('creation endpoint links to a real order when orderId is given', async t => {
    const router = require('../routes/lab/external-transfers');
    const order = {
        _id: 'order-1',
        labId: 'lab-1',
        status: 'at_lab',
        qrCode: 'LG-1234',
        tests: [{ testId: 't1', testName: 'CBC' }],
        patientId: { name: 'Patient One', phone: '111', gender: 'female', birthDate: '2000-01-01' },
    };
    t.mock.method(Order, 'findById', () => ({
        populate() { return this; },
        then: (resolve) => resolve(order),
    }));
    t.mock.method(ExternalTransfer, 'findOne', async () => null);
    let created = null;
    t.mock.method(ExternalTransfer, 'create', async (fields) => {
        created = fields;
        return { _id: 'transfer-1', ...fields };
    });

    const app = express();
    app.use(express.json());
    app.use((req, res, next) => {
        req.lab = { _id: 'lab-1' };
        req.user = { _id: 'lab-owner-1' };
        next();
    });
    app.use(router);
    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise(resolve => server.close(resolve)));

    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/external-transfers`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ orderId: 'order-1', labName: 'Reference Lab' }),
    });
    const body = await response.json();

    assert.equal(response.status, 201);
    assert.equal(body.success, true);
    assert.equal(created.orderId, 'order-1');
    assert.equal(created.sampleCode, 'LG-1234');
    assert.equal(created.patientName, 'Patient One');
});

test('send & receive page renders the app-style form, tracking and receive lists', async () => {
    const dictionary = require('../i18n/languages/en.json');
    const translate = key => readKey(dictionary, key) || key;
    const html = await ejs.renderFile(
        path.join(__dirname, '../views/dashboard/lab-orders.ejs'),
        {
            __: translate,
            lab: { name: 'Main Lab' },
            user: { name: 'Owner', email: 'owner@example.com' },
            title: 'Send & receive',
            currentLang: 'en',
            direction: 'ltr',
            font: 'Inter, sans-serif',
            activeSection: 'orders',
            tab: 'send',
            catalog: ['CBC', 'Lipid Profile'],
            preselectOrderId: '',
        },
        { filename: path.join(__dirname, '../views/dashboard/lab-orders.ejs') }
    );

    // send: the four steps of the app's form, then tracking with its search
    assert.match(html, /id="sendForm"/);
    for (const id of ['patientInput', 'phoneInput', 'ageInput', 'testInput', 'labInput', 'priceInput', 'sendBtn']) {
        assert.match(html, new RegExp(`id="${id}"`));
    }
    assert.match(html, /id="trackSearch"/);
    assert.match(html, /id="trackList"/);
    // receive: barcode box, received list with search and filters
    assert.match(html, /id="scanForm"/);
    assert.match(html, /id="recvSearch"/);
    assert.match(html, /data-f="on_the_way"/);
    // the lab's own tests reach the test search
    assert.match(html, /"catalog":\["CBC","Lipid Profile"\]/);
});
