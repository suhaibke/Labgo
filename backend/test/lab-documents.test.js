const { jwtSecret } = require('../config/secrets');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { Readable } = require('node:stream');
const test = require('node:test');

const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

const Lab = require('../models/Lab');
const User = require('../models/User');
const r2Service = require('../services/r2Service');
const labRoutes = require('../routes/admin/labs');

const documentFields = [
    'labCertificates',
    'labOpeningLetter',
    'labOpeningLicense',
    'practiceLicense',
    'ownerUnifiedCard',
    'ownerDepartmentOrRetirementId'
];

const adminId = '507f1f77bcf86cd799439011';
const ownerId = '507f191e810c19729de860ea';

function createAdmin() {
    return {
        _id: new mongoose.Types.ObjectId(adminId),
        id: adminId,
        name: 'Document Test Admin',
        email: 'document-admin@example.com',
        role: 'admin',
        status: 'active'
    };
}

function createOwner() {
    return {
        _id: new mongoose.Types.ObjectId(ownerId),
        id: ownerId,
        name: 'Document Test Owner',
        email: 'document-owner@example.com',
        role: 'patient',
        status: 'active'
    };
}

function queryResult(value) {
    const query = {
        select() { return query; },
        populate() { return query; },
        then(resolve, reject) { return Promise.resolve(value).then(resolve, reject); }
    };
    return query;
}

async function startRouterServer(t) {
    const app = express();
    app.use(express.json());
    app.use('/admin/api/labs', labRoutes);
    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise(resolve => server.close(resolve)));
    return `http://127.0.0.1:${server.address().port}`;
}

function adminToken() {
    return jwt.sign(
        { userId: adminId, role: 'admin' },
        jwtSecret()
    );
}

test('Lab schema stores optional private document groups', () => {
    const documentsPath = Lab.schema.path('documents');

    assert.ok(documentsPath, 'Lab.documents must exist');
    assert.equal(documentsPath.options.select, false);

    const lab = new Lab({
        name: 'Optional Documents Lab',
        email: 'optional-documents@example.com',
        phone: '07700000123',
        address: 'Baghdad',
        city: 'بغداد',
        country: 'Iraq',
        ownerId,
        createdBy: adminId
    });

    assert.equal(lab.validateSync(), undefined);
    for (const field of documentFields) {
        assert.ok(Array.isArray(lab.documents[field]), field);
        assert.equal(lab.documents[field].length, 0, field);
    }
});

test('lab document metadata is built only from uploaded document fields', () => {
    let helpers;
    assert.doesNotThrow(() => {
        helpers = require('../helpers/lab-documents');
    });

    const documents = helpers.buildLabDocuments({
        labCertificates: [{
            originalname: 'quality-certificate.pdf',
            mimetype: 'application/pdf',
            r2Url: '/uploads/labs/quality-certificate.pdf',
            r2: { key: 'uploads/labs/quality-certificate.pdf' }
        }],
        ownerUnifiedCard: [{
            originalname: 'owner-card-front.jpg',
            mimetype: 'image/jpeg',
            r2Url: '/uploads/labs/owner-card-front.jpg',
            r2: { key: 'uploads/labs/owner-card-front.jpg' }
        }],
        logo: [{
            originalname: 'logo.png',
            mimetype: 'image/png',
            r2Url: '/uploads/labs/logo.png',
            r2: { key: 'uploads/labs/logo.png' }
        }]
    });

    assert.deepEqual(Object.keys(documents), documentFields);
    assert.equal(documents.labCertificates.length, 1);
    assert.equal(documents.labCertificates[0].originalName, 'quality-certificate.pdf');
    assert.equal(documents.labCertificates[0].url, '/uploads/labs/quality-certificate.pdf');
    assert.equal(documents.labCertificates[0].storageKey, 'uploads/labs/quality-certificate.pdf');
    assert.equal(documents.labCertificates[0].mimeType, 'application/pdf');
    assert.ok(documents.labCertificates[0].uploadedAt instanceof Date);
    assert.equal(documents.ownerUnifiedCard.length, 1);
    assert.equal(documents.labOpeningLetter.length, 0);
    assert.equal(Object.hasOwn(documents, 'logo'), false);
});

test('add-lab page exposes every document input as optional image/PDF upload', () => {
    const source = fs.readFileSync(path.join(__dirname, '..', 'views', 'labs', 'add-lab.ejs'), 'utf8');

    for (const field of documentFields) {
        const input = source.match(new RegExp(`<input\\b[^>]*name="${field}"[^>]*>`, 'i'))?.[0];
        assert.ok(input, field);
        assert.match(input, /type="file"/i, field);
        assert.match(input, /accept="image\/\*,application\/pdf"/i, field);
        assert.doesNotMatch(input, /\brequired\b/i, field);
    }
});

test('lab creation accepts optional documents and stores their R2 metadata', async t => {
    const admin = createAdmin();
    const owner = createOwner();
    let savedLab;

    t.mock.method(User, 'findById', id => queryResult(String(id) === adminId ? admin : owner));
    t.mock.method(User, 'updateOne', async () => ({ acknowledged: true }));
    t.mock.method(Lab.prototype, 'save', async function saveWithoutDatabase() {
        savedLab = this;
        return this;
    });
    t.mock.method(Lab, 'findById', () => queryResult(savedLab));
    t.mock.method(r2Service, 'uploadFromMulter', async file => ({
        key: `uploads/labs/${file.originalname}`,
        url: `/uploads/labs/${file.originalname}`,
        contentType: file.mimetype
    }));

    const baseUrl = await startRouterServer(t);
    const form = new FormData();
    form.append('name', 'Uploaded Documents Lab');
    form.append('email', 'uploaded-documents@example.com');
    form.append('phone', '07700000456');
    form.append('address', 'Baghdad');
    form.append('city', 'بغداد');
    form.append('country', 'Iraq');
    form.append('ownerId', ownerId);
    form.append('labCertificates', new Blob(['certificate'], { type: 'application/pdf' }), 'quality-certificate.pdf');
    form.append('ownerUnifiedCard', new Blob(['identity'], { type: 'image/jpeg' }), 'owner-card-front.jpg');

    const response = await fetch(`${baseUrl}/admin/api/labs`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${adminToken()}` },
        body: form
    });
    const body = await response.json();

    assert.equal(response.status, 201);
    assert.equal(body.success, true);
    assert.equal(savedLab.documents.labCertificates.length, 1);
    assert.equal(savedLab.documents.labCertificates[0].originalName, 'quality-certificate.pdf');
    assert.equal(savedLab.documents.ownerUnifiedCard.length, 1);
    assert.equal(savedLab.documents.practiceLicense.length, 0);
});

test('lab document download route rejects unauthenticated access', async t => {
    const baseUrl = await startRouterServer(t);
    const response = await fetch(
        `${baseUrl}/admin/api/labs/507f1f77bcf86cd799439012/documents/ownerUnifiedCard/507f1f77bcf86cd799439013`
    );

    assert.equal(response.status, 401);
});

test('authenticated admin can stream a document belonging to the selected lab', async t => {
    const admin = createAdmin();
    const labId = '507f1f77bcf86cd799439012';
    const documentId = '507f1f77bcf86cd799439013';
    const documentBody = 'private-owner-document';
    const lab = {
        _id: labId,
        documents: {
            ownerUnifiedCard: [{
                _id: documentId,
                originalName: 'owner-card.pdf',
                mimeType: 'application/pdf',
                url: '/uploads/labs/owner-card.pdf'
            }]
        }
    };

    t.mock.method(User, 'findById', () => queryResult(admin));
    t.mock.method(Lab, 'findById', () => queryResult(lab));
    t.mock.method(r2Service, 'getFileStream', async fileUrl => {
        assert.equal(fileUrl, '/uploads/labs/owner-card.pdf');
        return {
            stream: Readable.from(documentBody),
            contentType: 'application/pdf',
            contentLength: Buffer.byteLength(documentBody)
        };
    });

    const baseUrl = await startRouterServer(t);
    const response = await fetch(
        `${baseUrl}/admin/api/labs/${labId}/documents/ownerUnifiedCard/${documentId}`,
        { headers: { Authorization: `Bearer ${adminToken()}` } }
    );

    assert.equal(response.status, 200);
    assert.equal(response.headers.get('content-type'), 'application/pdf');
    assert.match(response.headers.get('content-disposition'), /owner-card\.pdf/);
    assert.equal(await response.text(), documentBody);
});

test('admin lab profile renderer exposes protected document actions', () => {
    const source = fs.readFileSync(path.join(__dirname, '..', 'public', 'js', 'lab-management.js'), 'utf8');

    assert.match(source, /function renderLabDocuments\(/);
    assert.match(source, /function openLabDocument\(/);
    assert.match(source, /\/admin\/api\/labs\/\$\{[^}]+\}\/documents\//);
    assert.match(source, /Authorization.*Bearer/s);
});

test('all supported languages include lab document labels', () => {
    for (const locale of ['en', 'ar', 'ku', 'tr']) {
        const messages = require(`../i18n/languages/${locale}.json`);
        for (const key of [
            'documentsTitle',
            'documentsOptionalHint',
            'labCertificates',
            'labOpeningLetter',
            'labOpeningLicense',
            'practiceLicense',
            'ownerUnifiedCard',
            'ownerDepartmentOrRetirementId',
            'noDocuments'
        ]) {
            assert.equal(typeof messages.labManagement[key], 'string', `${locale}: ${key}`);
            assert.ok(messages.labManagement[key].length > 0, `${locale}: ${key}`);
        }
    }
});
