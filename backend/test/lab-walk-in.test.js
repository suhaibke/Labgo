const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const bcrypt = require('bcryptjs');
const express = require('express');
const mongoose = require('mongoose');

const User = require('../models/User');
const Order = require('../models/Order');
const Package = require('../models/Package');
const otpService = require('../services/otpService');
const Counter = require('../models/Counter');
const { createWalkInOrder, packageLines, birthDateFromAge } = require('../services/walkInOrderService');

const t1 = new mongoose.Types.ObjectId();
const t2 = new mongoose.Types.ObjectId();
const lab = {
    _id: new mongoose.Types.ObjectId(),
    name: 'Reception Lab',
    city: 'Mosul',
    address: 'Main St',
    coordinates: { latitude: 36.3, longitude: 43.1 },
    tests: [
        { _id: t1, name: 'CBC', code: 'CBC', price: 15000, category: 'Blood Tests' },
        { _id: t2, name: 'Vitamin D', code: 'VITD', price: 45000, category: 'Biochemistry' },
    ],
};
const staffId = new mongoose.Types.ObjectId();

function stubDb(t, existingUser = null) {
    const saved = { users: [], orders: [] };
    t.mock.method(User, 'findOne', async () => existingUser);
    t.mock.method(User.prototype, 'save', async function save() { saved.users.push(this); return this; });
    t.mock.method(Order.prototype, 'save', async function save() { await this.validate(); saved.orders.push(this); return this; });
    t.mock.method(Package, 'find', () => ({ lean: async () => [] }));
    t.mock.method(bcrypt, 'hash', async () => 'hashed');
    let seq = 100000;
    t.mock.method(Counter, 'next', async () => ++seq);
    t.mock.method(User, 'updateOne', async () => ({}));
    return saved;
}

test('a new phone creates a placeholder patient and an at-lab walk-in order', async (t) => {
    const saved = stubDb(t);
    const order = await createWalkInOrder(lab, staffId, {
        name: 'Ali Hassan', phone: '0770 123 4567', gender: 'male', age: 6, ageUnit: 'M',
        testIds: [String(t1), String(t2)], discount: 5000, doctor: 'Dr. Noor', sampleType: 'blood',
    });
    assert.equal(saved.users.length, 1);
    assert.equal(saved.users[0].labPlaceholder, true);
    assert.equal(saved.users[0].phone, '07701234567');
    assert.equal(saved.users[0].role, 'patient');
    assert.equal(order.status, 'at_lab');
    assert.equal(order.orderType, 'walk_in');
    assert.equal(order.pricing.subtotal, 60000);
    assert.equal(order.pricing.total, 55000);
    assert.equal(order.payment.status, 'paid');
    assert.equal(order.financials.labAmount, 55000);
    assert.equal(order.walkIn.doctor, 'Dr. Noor');
    assert.equal(String(order.patientId), String(saved.users[0]._id));
    assert.equal(order.$locals.patientNo, 100001, 'the patient gets an ID number');
});

test('a known phone with another name is saved as a beneficiary of that account', async (t) => {
    const parent = new User({ name: 'Mother', phone: '07701234567', password: 'x', role: 'patient' });
    const saved = stubDb(t, parent);
    const order = await createWalkInOrder(lab, staffId, {
        name: 'Baby Sara', phone: '07701234567', gender: 'female', age: 3, ageUnit: 'M', testIds: [String(t1)], payLater: true,
    });
    assert.equal(saved.users.length, 0, 'no new account');
    assert.equal(String(order.patientId), String(parent._id));
    assert.equal(order.beneficiary.isForOtherPerson, true);
    assert.equal(order.beneficiary.name, 'Baby Sara');
    assert.equal(order.payment.status, 'pending');
    assert.equal(order.$locals.patientNo, null, 'no ID for someone else on the account');
});

test('staff phones and empty orders are refused', async (t) => {
    stubDb(t, new User({ name: 'Nurse', phone: '07701234567', password: 'x', role: 'nurse' }));
    await assert.rejects(() => createWalkInOrder(lab, staffId, { name: 'X', phone: '07701234567', testIds: [String(t1)] }), /staff/);
    await assert.rejects(() => createWalkInOrder(lab, staffId, { name: 'X', phone: '07701234567', testIds: [] }), /at least one test/);
    await assert.rejects(() => createWalkInOrder(lab, staffId, { name: 'X', phone: '12', testIds: [String(t1)] }));
});

test('package price is split across its tests and adds up exactly', () => {
    const lines = packageLines({ price: 50000 }, lab.tests);
    assert.equal(lines.reduce((s, l) => s + l.price, 0), 50000);
    assert.equal(lines[0].price, 12500);
});

test('age in months gives a birth date months back', () => {
    const now = new Date('2026-11-12T00:00:00Z');
    assert.equal(birthDateFromAge(6, 'M', now).toISOString().slice(0, 7), '2026-05');
    assert.equal(birthDateFromAge(-1, 'Y', now), null);
});

test('registering with OTP claims a lab placeholder and keeps its id', async (t) => {
    const placeholder = new User({ name: 'Ali Hassan', phone: '07701234567', password: 'x', role: 'patient', labPlaceholder: true });
    const originalId = String(placeholder._id);
    t.mock.method(User, 'findOne', async (q) => (q.phone ? placeholder : null));
    t.mock.method(User.prototype, 'save', async function save() { return this; });
    t.mock.method(bcrypt, 'genSalt', async () => 'salt');
    t.mock.method(bcrypt, 'hash', async () => 'hashed-password');
    t.mock.method(otpService, 'verifyOtpLocal', () => ({ success: true }));

    const authApi = require('../routes/auth/auth');
    const app = express();
    app.use(express.json());
    app.use('/api/auth', authApi);
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise((resolve) => server.close(resolve)));

    const res = await fetch(`http://127.0.0.1:${server.address().port}/api/auth/register-with-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: 'Ali Hassan', phone: '07701234567', city: 'بغداد', gender: 'male', birthDate: '1990-01-02', password: 'Password123!', code: '123456' }),
    });
    const body = await res.json();
    assert.equal(res.status, 201, JSON.stringify(body));
    assert.equal(body.user.id, originalId);
    assert.equal(placeholder.labPlaceholder, false);
    assert.equal(placeholder.password, 'hashed-password');
});

test('a real account with the same phone still blocks registration', async (t) => {
    const real = new User({ name: 'Real', phone: '07701234567', password: 'x', role: 'patient' });
    t.mock.method(User, 'findOne', async (q) => (q.phone ? real : null));
    t.mock.method(otpService, 'verifyOtpLocal', () => ({ success: true }));
    const authApi = require('../routes/auth/auth');
    const app = express();
    app.use(express.json());
    app.use('/api/auth', authApi);
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise((resolve) => server.close(resolve)));
    const res = await fetch(`http://127.0.0.1:${server.address().port}/api/auth/register-with-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: 'Other', phone: '07701234567', city: 'بغداد', gender: 'female', birthDate: '1990-01-02', password: 'Password123!', code: '123456' }),
    });
    assert.equal(res.status, 409);
});

test('the receptionist can find a known patient by ID number', async (t) => {
    const { lookupPatient } = require('../services/walkInOrderService');
    const patient = new User({ name: 'Ali', phone: '07701234567', password: 'x', role: 'patient', patientNo: 100245, createdByLabId: lab._id });
    let query = null;
    t.mock.method(User, 'findOne', async (q) => { query = q; return patient; });
    const found = await lookupPatient(lab, '100245');
    assert.deepEqual(query, { patientNo: 100245, role: 'patient' });
    assert.equal(found.phone, '07701234567');
    assert.equal(found.patientNo, 100245);
});

test('a placeholder patient passes validation without a city or email', async () => {
    const u = new User({ name: 'Walk-in', phone: '07701230000', password: 'x', role: 'patient', labPlaceholder: true });
    await u.validate();
});

test('a company patient pays the B2B price when the lab set one', async (t) => {
    stubDb(t);
    const b2bLab = { ...lab, tests: [{ ...lab.tests[0], priceB2B: 9000 }, lab.tests[1]] };
    const order = await createWalkInOrder(b2bLab, staffId, {
        name: 'Clinic Patient', phone: '07701239999', company: 'Al-Noor Clinic', testIds: [String(t1), String(t2)],
    });
    assert.equal(order.tests[0].price, 9000);
    assert.equal(order.tests[1].price, 45000, 'no B2B price -> normal price');
});
