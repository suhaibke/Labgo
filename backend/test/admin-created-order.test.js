const secrets = require('../config/secrets');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const test = require('node:test');

const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

const Lab = require('../models/Lab');
const Order = require('../models/Order');
const User = require('../models/User');
const fcmService = require('../services/fcmService');
const telegramService = require('../services/telegramService');
const adminOrderRoutes = require('../routes/admin/orders');
const orderRoutes = require('../routes/orders');

const adminId = '507f1f77bcf86cd799439011';
const patientId = '507f191e810c19729de860ea';
const labId = '507f1f77bcf86cd799439012';
const testId = '507f191e810c19729de860eb';
const jwtSecret = secrets.jwtSecret();

function queryResult(value) {
    const query = {
        select() { return query; },
        populate() { return query; },
        sort() { return query; },
        limit() { return query; },
        skip() { return query; },
        lean() { return Promise.resolve(value); },
        then(resolve, reject) { return Promise.resolve(value).then(resolve, reject); }
    };
    return query;
}

function tokenFor(userId, role) {
    return jwt.sign({ userId, role }, jwtSecret);
}

function validOrderPayload(overrides = {}) {
    return {
        patientId,
        location: {
            address: 'Baghdad test address',
            coordinates: { latitude: 33.3152, longitude: 44.3661 }
        },
        labId,
        tests: [{
            testId,
            testName: 'Complete Blood Count',
            testCode: 'CBC',
            category: 'Blood Tests',
            price: 25000
        }],
        ...overrides
    };
}

async function startServer(t) {
    const app = express();
    app.use(express.json());
    app.use('/api/admin/orders', adminOrderRoutes);
    app.use('/api/orders', orderRoutes);

    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise(resolve => server.close(resolve)));
    return `http://127.0.0.1:${server.address().port}`;
}

test('admin order form requires selecting an existing mobile patient', () => {
    const source = fs.readFileSync(
        path.join(__dirname, '..', 'views', 'dashboard', 'admin-orders.ejs'),
        'utf8'
    );

    assert.match(source, /id="patientSearchInput"/);
    assert.match(source, /createOrderData\.patientId/);
    assert.doesNotMatch(source, /id="newPatientName"/);
    assert.doesNotMatch(source, /id="newPatientPhone"/);
    assert.doesNotMatch(source, /newPatient:\s*createOrderData\.newPatient/);
});

test('admin API rejects an order that is not linked to an existing patient account', async t => {
    const admin = { _id: new mongoose.Types.ObjectId(adminId), id: adminId, role: 'admin', status: 'active' };
    let createdPatient = false;
    let savedOrder = null;

    t.mock.method(User, 'findById', () => queryResult(admin));
    t.mock.method(User, 'findOne', async () => null);
    t.mock.method(User.prototype, 'save', async function savePatient() {
        createdPatient = true;
        return this;
    });
    t.mock.method(Lab, 'findById', () => queryResult({ _id: labId, name: 'Test Lab' }));
    t.mock.method(Order.prototype, 'save', async function saveOrder() {
        savedOrder = this;
        return this;
    });
    t.mock.method(Order, 'findById', () => queryResult(savedOrder));
    t.mock.method(telegramService, 'sendNewOrderNotification', async () => null);

    const baseUrl = await startServer(t);
    const response = await fetch(`${baseUrl}/api/admin/orders/create`, {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${tokenFor(adminId, 'admin')}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(validOrderPayload({
            patientId: null,
            newPatient: { name: 'Unlinked Patient', phone: '07700000000' }
        }))
    });
    const body = await response.json();

    assert.equal(response.status, 400);
    assert.equal(body.success, false);
    assert.match(body.message, /select.*patient/i);
    assert.equal(createdPatient, false);
    assert.equal(savedOrder, null);
});

test('admin-created order belongs to the selected user, appears in their mobile feed, and notifies them', async t => {
    const admin = { _id: new mongoose.Types.ObjectId(adminId), id: adminId, role: 'admin', status: 'active' };
    const patient = { _id: new mongoose.Types.ObjectId(patientId), id: patientId, role: 'patient', status: 'active' };
    let savedOrder = null;
    let mobileFeedQuery = null;
    const notificationCalls = [];

    t.mock.method(User, 'findById', id => queryResult(String(id) === adminId ? admin : patient));
    t.mock.method(Lab, 'findById', () => queryResult({ _id: labId, name: 'Test Lab' }));
    t.mock.method(Order.prototype, 'save', async function saveOrder() {
        this.createdAt = new Date('2026-08-05T09:00:00Z');
        savedOrder = this;
        return this;
    });
    t.mock.method(Order, 'findById', () => queryResult(savedOrder));
    t.mock.method(Order, 'find', query => {
        mobileFeedQuery = query;
        const orders = savedOrder && String(savedOrder.patientId) === String(query.patientId)
            ? [savedOrder]
            : [];
        return queryResult(orders);
    });
    t.mock.method(Order, 'countDocuments', async query => (
        savedOrder && String(savedOrder.patientId) === String(query.patientId) ? 1 : 0
    ));
    t.mock.method(fcmService, 'sendToUser', async (...args) => {
        notificationCalls.push(args);
        return { successCount: 1, failureCount: 0 };
    });
    t.mock.method(telegramService, 'sendNewOrderNotification', async () => null);

    const baseUrl = await startServer(t);
    const createResponse = await fetch(`${baseUrl}/api/admin/orders/create`, {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${tokenFor(adminId, 'admin')}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(validOrderPayload())
    });
    const createBody = await createResponse.json();

    assert.equal(createResponse.status, 201);
    assert.equal(createBody.success, true);
    assert.equal(String(savedOrder.patientId), patientId);

    const mobileResponse = await fetch(`${baseUrl}/api/orders/my-orders`, {
        headers: { Authorization: `Bearer ${tokenFor(patientId, 'patient')}` }
    });
    const mobileBody = await mobileResponse.json();

    assert.equal(mobileResponse.status, 200);
    assert.equal(String(mobileFeedQuery.patientId), patientId);
    assert.equal(mobileBody.data.orders.length, 1);
    assert.equal(mobileBody.data.orders[0]._id, String(savedOrder._id));
    assert.equal(notificationCalls.length, 1);
    assert.equal(String(notificationCalls[0][0]), patientId);
    assert.equal(notificationCalls[0][3].type, 'order_accepted');
    assert.equal(notificationCalls[0][3].orderId, String(savedOrder._id));
});
