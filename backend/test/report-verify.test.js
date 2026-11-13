const assert = require('node:assert/strict');
const http = require('node:http');
const path = require('node:path');
const test = require('node:test');
const express = require('express');
const mongoose = require('mongoose');
const Order = require('../models/Order');
const { verifyUrl, checkSignature } = require('../services/reportPdfService');
const router = require('../routes/report-verify');

test('patient names are masked on the public page', () => {
    assert.equal(router.maskName('Sara Ali Hussein'), 'Sara A. H.');
    assert.equal(router.maskName('سارة علي'), 'سارة ع.');
});

test('a signature only matches the same order and approval time', () => {
    const id = String(new mongoose.Types.ObjectId());
    const at = new Date('2026-11-13T08:40:00Z');
    const sig = new URL(verifyUrl('https://labgo.iq', id, at)).searchParams.get('s');
    assert.equal(checkSignature(id, at, sig), true);
    assert.equal(checkSignature(id, new Date('2026-11-13T08:41:00Z'), sig), false, 'a re-approved report gets a new code');
    assert.equal(checkSignature(id, at, sig.slice(0, -1) + (sig.endsWith('a') ? 'b' : 'a')), false);
    assert.equal(checkSignature(id, at, ''), false);
});

test('the page confirms a valid report and refuses a tampered link', async (t) => {
    const id = new mongoose.Types.ObjectId();
    const at = new Date('2026-11-13T08:40:00Z');
    const order = new Order({ _id: id, qrCode: 'LG-1', tests: [], results: { entryStatus: 'approved', approvedAt: at },
        beneficiary: { isForOtherPerson: true, name: 'Sara Ali' } });
    const q = { select() { return q; }, populate() { return q; }, then(r) { return Promise.resolve(order).then(r); } };
    t.mock.method(Order, 'findById', () => q);
    const app = express();
    app.set('view engine', 'ejs');
    app.set('views', path.join(__dirname, '../views'));
    app.use(router);
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise((resolve) => server.close(resolve)));
    const base = `http://127.0.0.1:${server.address().port}`;
    const good = new URL(verifyUrl(base, String(id), at));
    let res = await fetch(good);
    assert.equal(res.status, 200);
    const html = await res.text();
    assert.match(html, /Sara A\./);
    assert.doesNotMatch(html, /Sara Ali/);
    res = await fetch(`${base}/verify-report/${id}?s=0000000000`);
    assert.equal(res.status, 404);
});
