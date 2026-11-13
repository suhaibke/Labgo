const secrets = require('../config/secrets');
const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');

const User = require('../models/User');
const Lab = require('../models/Lab');
const { footerTemplate, barcodeDataUrl } = require('../services/reportPdfService');

const jwtSecret = secrets.jwtSecret();

test('the LabGo footer is shown unless the platform hides it', () => {
    const shown = footerTemplate({ showPlatform: true, left: 'Lab · LG-1' });
    assert.match(shown, /Powered by/);
    assert.match(shown, /data:image\/png;base64,/);
    assert.match(shown, /pageNumber/);
    const hidden = footerTemplate({ showPlatform: false, left: 'Lab · LG-1' });
    assert.doesNotMatch(hidden, /Powered by|LabGo laboratory/);
    assert.match(hidden, /Lab · LG-1/);
});

test('the order number becomes a Code 128 barcode', () => {
    const url = barcodeDataUrl('LG-2026-4820');
    assert.match(url, /^data:image\/svg\+xml;base64,/);
    assert.match(Buffer.from(url.split(',')[1], 'base64').toString(), /<svg/);
    assert.equal(barcodeDataUrl(''), null);
});

async function adminServer(t, role, lab) {
    const userId = new mongoose.Types.ObjectId();
    t.mock.method(User, 'findById', () => ({ select: async () => ({ _id: userId, id: String(userId), role, status: 'active' }) }));
    t.mock.method(Lab, 'findById', async () => lab);
    const app = express();
    app.use(express.json());
    app.use('/admin/api/labs', require('../routes/admin/labs'));
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise((resolve) => server.close(resolve)));
    const token = jwt.sign({ userId: String(userId), role }, jwtSecret);
    return (body) => fetch(`http://127.0.0.1:${server.address().port}/admin/api/labs/${lab._id}/report-branding`, {
        method: 'PATCH', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` }, body: JSON.stringify(body),
    });
}

test('only a platform admin can hide the footer', async (t) => {
    const lab = new Lab({ name: 'L', ownerId: new mongoose.Types.ObjectId(), phone: '0', email: 'l@l.l' });
    lab.save = async function save() { return this; };
    assert.equal(lab.reportBranding.hidePlatformFooter, false, 'shown by default');

    const asLab = await adminServer(t, 'lab', lab);
    let res = await asLab({ hidePlatformFooter: true });
    assert.ok(res.status === 401 || res.status === 403, `lab refused (got ${res.status})`);
    assert.equal(lab.reportBranding.hidePlatformFooter, false);
});

test('the admin route needs a true/false value and saves it', async (t) => {
    const lab = new Lab({ name: 'L', ownerId: new mongoose.Types.ObjectId(), phone: '0', email: 'l@l.l' });
    lab.save = async function save() { return this; };
    const asAdmin = await adminServer(t, 'admin', lab);
    assert.equal((await asAdmin({ hidePlatformFooter: 'yes' })).status, 400);
    const res = await asAdmin({ hidePlatformFooter: true });
    assert.equal(res.status, 200);
    assert.equal(lab.reportBranding.hidePlatformFooter, true);
});
