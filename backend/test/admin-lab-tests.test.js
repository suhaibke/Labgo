const { jwtSecret } = require('../config/secrets');
const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

const Lab = require('../models/Lab');
const User = require('../models/User');
const labRoutes = require('../routes/admin/labs');

const adminId = '507f1f77bcf86cd799439011';
const ownerId = '507f191e810c19729de860ea';
const labId = '6ae4c754d9df1ab528c485c0';
const secret = jwtSecret();

function queryResult(value) {
    const query = {
        select() { return query; },
        populate() { return query; },
        then(resolve, reject) { return Promise.resolve(value).then(resolve, reject); }
    };
    return query;
}

function createUser(role) {
    return {
        _id: new mongoose.Types.ObjectId(adminId),
        id: adminId,
        name: 'Test User',
        email: 'test-user@example.com',
        role,
        status: 'active'
    };
}

function createLab() {
    return new Lab({
        _id: labId,
        name: 'مختبر العافية',
        email: 'lab@example.com',
        phone: '07700000123',
        address: 'Baghdad',
        city: 'بغداد',
        country: 'Iraq',
        ownerId,
        createdBy: adminId
    });
}

async function postTest(t, { body, role = 'admin', lab = createLab() }) {
    t.mock.method(User, 'findById', () => queryResult(createUser(role)));
    t.mock.method(Lab, 'findById', () => queryResult(lab));
    const save = t.mock.method(Lab.prototype, 'save', async function saveWithoutDatabase() {
        return this;
    });

    const app = express();
    app.use(express.json());
    app.use('/admin/api/labs', labRoutes);
    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise(resolve => server.close(resolve)));

    const response = await fetch(`http://127.0.0.1:${server.address().port}/admin/api/labs/${labId}/tests`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${jwt.sign({ userId: adminId, role }, secret)}`
        },
        body: JSON.stringify(body)
    });

    return { response, payload: await response.json(), save, lab };
}

const validBody = {
    name: ' Vitamin D ',
    nameAr: ' فيتامين د ',
    price: '15000.4',
    category: 'Biochemistry',
    description: 'Serum level',
    instructions: 'No fasting needed'
};

test('admin adds a test to a lab', async t => {
    const { response, payload, save, lab } = await postTest(t, { body: validBody });

    assert.equal(response.status, 201);
    assert.equal(payload.success, true);
    assert.equal(save.mock.callCount(), 1);
    assert.equal(lab.tests.length, 1);

    const added = lab.tests[0];
    assert.equal(added.name, 'Vitamin D');
    assert.equal(added.nameAr, 'فيتامين د');
    assert.equal(added.price, 15000);
    assert.equal(added.category, 'Biochemistry');
    assert.equal(added.description, 'Serum level');
    assert.equal(added.instructions, 'No fasting needed');
    assert.match(added.code, /^BIOCHEMISTRY_\d+$/);
    assert.equal(String(payload.data._id), String(added._id));
    assert.equal(lab.validateSync(), undefined);
});

for (const [label, override] of [
    ['English name', { name: '   ' }],
    ['Arabic name', { nameAr: '' }],
    ['price', { price: '' }],
    ['non-numeric price', { price: 'abc' }],
    ['negative price', { price: -1 }],
    ['category outside the model enum', { category: 'Astrology' }]
]) {
    test(`admin add test rejects invalid ${label}`, async t => {
        const { response, payload, save, lab } = await postTest(t, { body: { ...validBody, ...override } });

        assert.equal(response.status, 400);
        assert.equal(payload.success, false);
        assert.equal(save.mock.callCount(), 0);
        assert.equal(lab.tests.length, 0);
    });
}

test('admin add test returns 404 for an unknown lab', async t => {
    const { response, save } = await postTest(t, { body: validBody, lab: null });

    assert.equal(response.status, 404);
    assert.equal(save.mock.callCount(), 0);
});

test('non-admin users cannot add tests through the admin route', async t => {
    const { response, save, lab } = await postTest(t, { body: validBody, role: 'lab' });

    assert.equal(response.status, 403);
    assert.equal(save.mock.callCount(), 0);
    assert.equal(lab.tests.length, 0);
});
