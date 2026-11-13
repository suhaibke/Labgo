const assert = require('node:assert/strict');
const test = require('node:test');
const mongoose = require('mongoose');
const Order = require('../models/Order');
const { toAppPatient, toCatalog } = require('../routes/lab/app-api');

function order(fields) {
    const o = new Order({
        patientId: new mongoose.Types.ObjectId(), labId: new mongoose.Types.ObjectId(), qrCode: 'LG-1',
        location: { address: 'x', coordinates: { latitude: 0, longitude: 0 } },
        tests: [{ testId: new mongoose.Types.ObjectId(), testName: 'CBC', testCode: 'CBC', price: 15000 }],
        pricing: { subtotal: 15000, total: 15000 }, payment: { amount: 15000, status: 'paid' }, ...fields,
    });
    return o;
}

test('an order becomes an app patient with its results, ID and status', () => {
    const o = order({ status: 'at_lab', orderType: 'walk_in', urgency: 'urgent',
        walkIn: { doctor: 'Dr. Noor', company: 'Clinic', sampleType: 'urine' },
        beneficiary: { isForOtherPerson: true, name: 'Baby', gender: 'female', birthDate: new Date(Date.now() - 90 * 86400000) },
        results: { values: [{ testName: 'CBC', value: '13.1' }], entryStatus: 'draft' } });
    const p = toAppPatient(o);
    assert.equal(p.name, 'Baby');
    assert.equal(p.gender, 'Female');
    assert.equal(p.age, '3M');
    assert.deepEqual(p.tests, ['CBC']);
    assert.deepEqual(p.results, { CBC: '13.1' });
    assert.equal(p.status, 'Pending');
    assert.equal(p.sample, 'Urine');
    assert.equal(p.urgency, 'Urgent');
    assert.equal(p.mode, 'B2B');
    assert.equal(p.permanent, 'LG-1', 'no patient ID for someone on another account');

    const done = toAppPatient(order({ status: 'completed' }));
    assert.equal(done.status, 'Completed');
    const unpaid = toAppPatient(order({ status: 'at_lab', orderType: 'walk_in', payment: { amount: 1, status: 'pending' } }));
    assert.equal(unpaid.status, 'Payment Pending');
});

test('catalog gives each test its ranges and a hidden Arabic-name entry', () => {
    const c = toCatalog([{ _id: 't1', name: 'Hemoglobin', nameAr: 'الهيموغلوبين', price: 5000, unit: 'g/dL',
        ranges: [{ gender: 'Female', ageFrom: 0, ageTo: 120, ageUnit: 'Y', min: 12, max: 15.5 }] }]);
    assert.equal(c.length, 2);
    assert.equal(c[0].on, true);
    assert.deepEqual(c[0].ranges[0], { ageFrom: '0', ageTo: '120', ageUnit: 'Y', gender: 'Female', min: '12', max: '15.5' });
    assert.equal(c[1].name, 'الهيموغلوبين');
    assert.equal(c[1].on, false);
    assert.equal(c[1].units, 'g/dL');
});

test('licence holders round-trip through the app text field', () => {
    const { textToHolders, holdersToText } = require('../routes/lab/app-api');
    const list = textToHolders('Dr. Ahmed Hamdoon Ahmed · Bacteriologist\nأ.د. سارة علي - اختصاص علم الأمراض, Mr. Omar');
    assert.deepEqual(list, [
        { title: 'Dr.', name: 'Ahmed Hamdoon Ahmed', specialty: 'Bacteriologist' },
        { title: 'أ.د.', name: 'سارة علي', specialty: 'اختصاص علم الأمراض' },
        { title: 'Mr.', name: 'Omar', specialty: '' },
    ]);
    assert.equal(holdersToText(list), 'Dr. Ahmed Hamdoon Ahmed · Bacteriologist\nأ.د. سارة علي · اختصاص علم الأمراض\nMr. Omar');
});

test('a transfer becomes an app referral', () => {
    const { toReferral } = require('../routes/lab/app-api');
    const r = toReferral({ _id: 'x', patientName: 'Sara', tests: [{ testName: 'Vitamin D' }], externalLab: { name: 'Al-Noor' }, status: 'sent', referenceNumber: 'EXT-1', expectedResultAt: new Date(2026, 10, 15) });
    assert.deepEqual(r, { id: 'x', patient: 'Sara', test: 'Vitamin D', lab: 'Al-Noor', status: 'Sent', eta: '15/11/2026', tracking: 'EXT-1', step: 1 });
    assert.equal(toReferral({ _id: 'y', status: 'completed', sampleCode: 'S-1' }).step, 3);
});

const http = require('node:http');
const express = require('express');
const Lab = require('../models/Lab');
const Package = require('../models/Package');

function labWithTests() {
    const lab = new Lab({ name: 'L', ownerId: new mongoose.Types.ObjectId(), createdBy: new mongoose.Types.ObjectId(), city: 'Mosul', phone: '0', email: 'l@l.l',
        tests: [{ name: 'CBC', code: 'CBC', price: 15000 }, { name: 'Sugar', nameAr: 'السكر', code: 'GLU', price: 10000 }] });
    lab.save = async function save() { await this.validate(); return this; };
    return lab;
}

async function appServer(t, lab) {
    t.mock.method(Lab, 'findById', async () => lab);
    const app = express();
    app.use(express.json());
    app.use((req, res, next) => { req.lab = lab; req.user = { _id: new mongoose.Types.ObjectId() }; next(); });
    app.use(require('../routes/lab/app-api'));
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise((resolve) => server.close(resolve)));
    return (path, body) => fetch(`http://127.0.0.1:${server.address().port}${path}`, {
        method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    }).then(async (r) => ({ status: r.status, json: await r.json() }));
}

test('the app edits a test: price, B2B price, on/off, unit and ranges', async (t) => {
    const lab = labWithTests();
    const put = await appServer(t, lab);
    const id = String(lab.tests[0]._id);
    const res = await put('/api/app/tests', { id, price: 16000, priceB2B: 12000, on: false, units: 'g/dL', category: 'Vitamins',
        ranges: [{ ageFrom: '18', ageTo: '99', ageUnit: 'Y', gender: 'Male', min: '13.5', max: '17.5' }] });
    assert.equal(res.status, 200);
    const cbc = lab.tests[0];
    assert.equal(cbc.price, 16000);
    assert.equal(cbc.priceB2B, 12000);
    assert.equal(cbc.isActive, false);
    assert.equal(cbc.unit, 'g/dL');
    assert.equal(cbc.category, 'Blood Tests', 'unknown categories keep the old one');
    assert.equal(cbc.ranges[0].min, 13.5);
    assert.equal(res.json.data.test.on, false);
});

test('the app adds a test and refuses a duplicate name', async (t) => {
    const lab = labWithTests();
    const put = await appServer(t, lab);
    const res = await put('/api/app/tests', { name: 'Vitamin D', price: 40000, units: 'ng/mL' });
    assert.equal(res.status, 200);
    assert.equal(lab.tests.length, 3);
    assert.equal(res.json.data.test.name, 'Vitamin D');
    assert.match(res.json.data.test.id, /^[a-f0-9]{24}$/);
    assert.equal((await put('/api/app/tests', { name: 'cbc' })).status, 409);
});

test('packages are saved by test names and need two tests', async (t) => {
    const lab = labWithTests();
    const put = await appServer(t, lab);
    let saved = null;
    t.mock.method(Package.prototype, 'save', async function save() { await this.validate(); saved = this; return this; });
    assert.equal((await put('/api/app/packages', { id: 'pkg-123', name: 'Check', tests: ['CBC'], price: 20000 })).status, 400);
    const res = await put('/api/app/packages', { id: 'pkg-123', name: 'Check', tests: ['CBC', 'السكر'], price: 20000, active: true });
    assert.equal(res.status, 200);
    assert.equal(saved.testIds.length, 2);
    assert.equal(res.json.data.id, String(saved._id));
});
