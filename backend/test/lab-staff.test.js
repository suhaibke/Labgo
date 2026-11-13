const secrets = require('../config/secrets');
const assert = require('node:assert/strict');
const http = require('node:http');
const path = require('node:path');
const test = require('node:test');
const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const fcmPath = path.join(__dirname, '../services/fcmService.js');
require.cache[fcmPath] = { id: fcmPath, filename: fcmPath, loaded: true, exports: { sendToUser: async () => {} } };

const User = require('../models/User');
const Lab = require('../models/Lab');
const { canAccess, requiredFor, labRoles } = require('../helpers/lab-permissions');

const jwtSecret = secrets.jwtSecret();

test('every lab route has a permission rule (none left owner-only by accident)', () => {
    const routers = ['dashboard', 'external-transfers', 'results', 'walk-in', 'staff', 'lab-finance-page', 'lab-waste-page', 'app-api', 'transfers-in', 'market-support'].map((f) => require(`../routes/lab/${f}`));
    const paths = new Set();
    for (const r of routers) {
        for (const layer of r.stack) if (layer.route) paths.add(layer.route.path.replace(/:[a-zA-Z]+/g, 'x'));
    }
    const ownerOnly = [...paths].filter((p) => requiredFor(p) === 'owner');
    assert.deepEqual(ownerOnly, []);
});

test('roles decide what staff can open', () => {
    const roles = labRoles({ staffRoles: [] });
    const perms = (key) => roles.find((r) => r.key === key).permissions;
    assert.equal(canAccess('/patients/new', perms('receptionist'), false), true);
    assert.equal(canAccess('/orders/abc/results', perms('receptionist'), false), false);
    assert.equal(canAccess('/api/orders/abc/results/approve', perms('technician'), false), true);
    assert.equal(canAccess('/settings', perms('technician'), false), false);
    assert.equal(canAccess('/reports', perms('accountant'), false), true);
    assert.equal(canAccess('/api/staff', perms('accountant'), false), false);
    assert.equal(canAccess('/dashboard', perms('guest'), false), true);
    assert.equal(canAccess('/api/tests', perms('guest'), false), false);
    assert.equal(canAccess('/anything-new', [], true), true, 'owner can open everything');
});

test('a lab can override a built-in role but the manager keeps every permission', () => {
    const roles = labRoles({ staffRoles: [{ key: 'admin', permissions: [] }, { key: 'technician', permissions: ['results'] }, { key: 'c-abcdef12', name: 'Driver', permissions: ['waste', 'bogus'] }] });
    assert.equal(roles.find((r) => r.key === 'admin').permissions.length, 9);
    assert.deepEqual(roles.find((r) => r.key === 'technician').permissions, ['results']);
    assert.deepEqual(roles.find((r) => r.key === 'c-abcdef12').permissions, ['waste']);
});

function labApp(t, staffUser, lab) {
    t.mock.method(User, 'findById', () => ({ select() { return this; }, then(resolve) { return Promise.resolve(staffUser).then(resolve); } }));
    t.mock.method(Lab, 'findOne', async () => null);
    t.mock.method(Lab, 'findById', async () => lab);
    const app = express();
    app.use(express.json());
    app.use((req, res, next) => { req.cookies = { token: jwt.sign({ userId: String(staffUser._id) }, jwtSecret) }; next(); });
    app.use('/lab', require('../routes/lab/dashboard'));
    return app;
}

async function listen(t, app) {
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise((resolve) => server.close(resolve)));
    return `http://127.0.0.1:${server.address().port}`;
}

test('a receptionist is refused results and settings APIs, a disabled account everything', async (t) => {
    const lab = new Lab({ name: 'L', ownerId: new mongoose.Types.ObjectId(), phone: '0', email: 'l@l.l' });
    const staff = new User({ name: 'Reception', phone: '07701112222', password: 'x', role: 'lab', labStaff: { labId: lab._id, roleKey: 'receptionist', active: true } });
    const base = await listen(t, labApp(t, staff, lab));
    const json = { headers: { Accept: 'application/json' } };

    let res = await fetch(`${base}/lab/api/orders/abc/results`, json);
    assert.equal(res.status, 403);
    res = await fetch(`${base}/lab/api/staff`, json);
    assert.equal(res.status, 403);
    res = await fetch(`${base}/lab/settings`, { redirect: 'manual' });
    assert.equal(res.status, 302);
    assert.equal(res.headers.get('location'), '/lab/patients/new');

    staff.labStaff.active = false;
    res = await fetch(`${base}/lab/api/stats`, json);
    assert.equal(res.status, 403);
});

test('creating staff hashes the password, links the lab and refuses taken phones', async (t) => {
    const lab = new Lab({ name: 'L', ownerId: new mongoose.Types.ObjectId(), phone: '0', email: 'l@l.l' });
    const router = require('../routes/lab/staff');
    const created = [];
    let taken = false;
    t.mock.method(User, 'findOne', async (q) => (q.phone && taken ? { _id: 'x' } : null));
    t.mock.method(User.prototype, 'save', async function save() { created.push(this); return this; });
    t.mock.method(bcrypt, 'hash', async () => 'hashed');
    const app = express();
    app.use(express.json());
    app.use((req, res, next) => { req.lab = lab; req.user = { _id: lab.ownerId }; req.isLabOwner = true; next(); });
    app.use(router);
    const base = await listen(t, app);
    const post = (body) => fetch(`${base}/api/staff`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

    let res = await post({ name: 'Tech', phone: '0770 222 3333', password: 'secret1', roleKey: 'technician' });
    assert.equal(res.status, 201);
    assert.equal(created[0].role, 'lab');
    assert.equal(created[0].password, 'hashed');
    assert.equal(String(created[0].labStaff.labId), String(lab._id));
    assert.equal(created[0].phone, '07702223333');

    res = await post({ name: 'Tech', phone: '0770 222 3333', password: '123', roleKey: 'technician' });
    assert.equal((await res.json()).code, 'password');
    res = await post({ name: 'Tech', phone: '0770 222 3333', password: 'secret1', roleKey: 'nope' });
    assert.equal((await res.json()).code, 'role');
    taken = true;
    res = await post({ name: 'Tech', phone: '0770 222 3333', password: 'secret1', roleKey: 'technician' });
    assert.equal(res.status, 409);
});

test('lab staff can be saved without an email, a lab owner still needs one', async () => {
    const staff = new User({ name: 'Tech', phone: '07703334444', password: 'x', role: 'lab', labStaff: { labId: new mongoose.Types.ObjectId(), roleKey: 'technician' } });
    await staff.validate();
    const owner = new User({ name: 'Owner', phone: '07705556666', password: 'x', role: 'lab' });
    await assert.rejects(() => owner.validate(), /Email is required/);
});

test('licence holders are trimmed, need a name and are capped at six', () => {
    const { cleanLicenseHolders } = require('../routes/lab/dashboard');
    const out = cleanLicenseHolders([
        { title: ' Dr. ', name: '  Ahmed   Hamdoon Ahmed ', specialty: 'Bacteriologist' },
        { title: 'Dr.', name: '', specialty: 'nobody' },
        ...Array.from({ length: 8 }, (_, i) => ({ name: `Person ${i}`, specialty: 'x'.repeat(200) })),
    ]);
    assert.equal(out.length, 6);
    assert.deepEqual(out[0], { title: 'Dr.', name: 'Ahmed Hamdoon Ahmed', specialty: 'Bacteriologist' });
    assert.equal(out[1].specialty.length, 60);
    assert.deepEqual(cleanLicenseHolders('nope'), []);
});
