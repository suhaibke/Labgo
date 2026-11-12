const assert = require('node:assert/strict');
const http = require('node:http');
const path = require('node:path');
const test = require('node:test');

const bcrypt = require('bcryptjs');
const ejs = require('ejs');
const express = require('express');

const Lab = require('../models/Lab');
const User = require('../models/User');
const authApi = require('../routes/auth/auth');

async function startAuthServer(t) {
    const app = express();
    app.use(express.json());
    app.use('/api/auth', authApi);

    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise(resolve => server.close(resolve)));
    return `http://127.0.0.1:${server.address().port}`;
}

async function postLogin(baseUrl, loginInput, password) {
    const response = await fetch(`${baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ loginInput, password })
    });
    return { response, body: await response.json() };
}

function labOwner(passwordHash) {
    return {
        _id: '507f1f77bcf86cd799439011',
        name: 'Phone Login Lab Owner',
        email: 'owner@example.com',
        phone: '07501234567',
        password: passwordHash,
        role: 'lab',
        status: 'active',
        city: 'بغداد',
        gender: null,
        birthDate: null
    };
}

test('management login form visibly accepts a phone number as the username', async () => {
    const html = await ejs.renderFile(path.join(__dirname, '..', 'views', 'auth', 'login.ejs'), {
        __: key => ({
            'auth.login.identifier': 'Phone number or email',
            'auth.login.identifierPlaceholder': 'Enter your phone number or email'
        })[key] || key,
        currentLang: 'en',
        direction: 'ltr',
        font: 'Inter, sans-serif',
        storeLinks: { android: '#android', ios: '#ios' },
        error: null
    });

    assert.match(html, /<label for="loginInput">Phone number or email<\/label>/);
    assert.match(html, /type="text"\s+id="loginInput"/);
    assert.match(html, /autocomplete="username"/);
    assert.doesNotMatch(html, /type="email"\s+id="loginInput"/);
});

test('lab owner can log in with a formatted Iraqi owner phone number', async t => {
    const password = 'PhoneLogin123!';
    const owner = labOwner(await bcrypt.hash(password, 4));

    t.mock.method(User, 'findOne', async query => (
        query.phone === owner.phone ? owner : null
    ));
    t.mock.method(Lab, 'findOne', async () => null);

    const baseUrl = await startAuthServer(t);
    const { response, body } = await postLogin(baseUrl, '+964 750 123 4567', password);

    assert.equal(response.status, 200);
    assert.equal(body.success, true);
    assert.equal(body.user.role, 'lab');
    assert.equal(body.user.id, owner._id);
});

test('lab owner can log in with the laboratory contact phone and owner password', async t => {
    const password = 'PhoneLogin123!';
    const owner = labOwner(await bcrypt.hash(password, 4));
    const labPhone = '07701234567';

    t.mock.method(User, 'findOne', async () => null);
    t.mock.method(Lab, 'findOne', async query => (
        query.phone === labPhone ? { ownerId: owner._id } : null
    ));
    t.mock.method(User, 'findById', async id => (
        String(id) === owner._id ? owner : null
    ));

    const baseUrl = await startAuthServer(t);
    const { response, body } = await postLogin(baseUrl, labPhone, password);

    assert.equal(response.status, 200);
    assert.equal(body.success, true);
    assert.equal(body.user.role, 'lab');
    assert.equal(body.user.id, owner._id);
});

test('all supported languages provide phone-or-email login labels', () => {
    for (const locale of ['en', 'ar', 'ku', 'tr']) {
        const messages = require(`../i18n/languages/${locale}.json`);
        assert.equal(typeof messages.auth.login.identifier, 'string', locale);
        assert.ok(messages.auth.login.identifier.length > 0, locale);
        assert.equal(typeof messages.auth.login.identifierPlaceholder, 'string', locale);
        assert.ok(messages.auth.login.identifierPlaceholder.length > 0, locale);
    }
});
