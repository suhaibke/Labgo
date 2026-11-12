const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const bcrypt = require('bcryptjs');
const express = require('express');

const { buildPublicPatient } = require('../helpers/public-registration');
const authPages = require('../routes/auth/pages');
const authApi = require('../routes/auth/auth');
const User = require('../models/User');

test('public registration always creates a patient even when a privileged role is submitted', () => {
    const patient = buildPublicPatient({
        name: 'Patient One',
        email: 'patient@example.com',
        phone: '07700000000',
        city: 'بغداد',
        gender: 'female',
        birthDate: '2000-01-02',
        role: 'admin',
        status: 'blocked'
    }, 'hashed-password');

    assert.deepEqual(patient, {
        name: 'Patient One',
        email: 'patient@example.com',
        phone: '07700000000',
        city: 'بغداد',
        gender: 'female',
        birthDate: '2000-01-02',
        password: 'hashed-password',
        role: 'patient'
    });
});

test('OTP public registration marks the phone verified without accepting a role override', () => {
    const patient = buildPublicPatient({
        name: 'Patient Two',
        email: 'patient2@example.com',
        phone: '07800000000',
        city: 'البصرة',
        gender: 'male',
        birthDate: '1995-03-04',
        role: 'lab'
    }, 'hashed-password', { phoneVerified: true });

    assert.equal(patient.role, 'patient');
    assert.equal(patient.phoneVerified, true);
    assert.equal(Object.hasOwn(patient, 'status'), false);
});

test('public registration API ignores a submitted lab role', async t => {
    t.mock.method(User, 'findOne', async () => null);
    t.mock.method(bcrypt, 'genSalt', async () => 'salt');
    t.mock.method(bcrypt, 'hash', async () => 'hashed-password');
    t.mock.method(User.prototype, 'save', async function saveWithoutDatabase() { return this; });

    const app = express();
    app.use(express.json());
    app.use('/api/auth', authApi);
    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise(resolve => server.close(resolve)));

    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            name: 'Patient Three',
            email: 'patient3@example.com',
            phone: '07701234567',
            city: 'بغداد',
            gender: 'female',
            birthDate: '2000-01-02',
            password: 'Password123!',
            role: 'lab'
        })
    });
    const body = await response.json();

    assert.equal(response.status, 201);
    assert.equal(body.user.role, 'patient');
});

test('website registration and OTP pages redirect to management login', async (t) => {
    const app = express();
    app.use('/auth', authPages);
    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise(resolve => server.close(resolve)));

    const { port } = server.address();
    for (const path of ['/auth/register', '/auth/otp']) {
        const response = await fetch(`http://127.0.0.1:${port}${path}`, {
            redirect: 'manual'
        });
        assert.equal(response.status, 302);
        assert.equal(response.headers.get('location'), '/auth/login');
    }
});
