const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const mongoose = require('mongoose');
const LabWaste = require('../models/LabWaste');
const Counter = require('../models/Counter');

const labId = new mongoose.Types.ObjectId();

async function start(t) {
    const app = express();
    app.use(express.json());
    app.use((req, res, next) => { req.lab = { _id: labId }; req.user = { _id: 'u1' }; next(); });
    app.use(require('../routes/lab/lab-waste-page'));
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise((resolve) => server.close(resolve)));
    return `http://127.0.0.1:${server.address().port}`;
}

test('a waste request needs a known type and a positive weight', async (t) => {
    const created = [];
    t.mock.method(LabWaste, 'create', async (doc) => { created.push(doc); return doc; });
    t.mock.method(Counter, 'next', async () => 1001);
    const base = await start(t);
    const post = (body) => fetch(`${base}/api/waste`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    assert.equal((await post({ type: 'nuclear', weightKg: 2 })).status, 400);
    assert.equal((await post({ type: 'sharps', weightKg: 0 })).status, 400);
    assert.equal((await post({ type: 'sharps', weightKg: '2.456', company: 'Green' })).status, 201);
    assert.equal(created[0].weightKg, 2.46);
    assert.equal(String(created[0].labId), String(labId));
    assert.equal(created[0].requestNo, 1001, 'each request gets a number for its report');
});

test('only this lab\'s pending requests can be deleted', async (t) => {
    let query = null;
    t.mock.method(LabWaste, 'deleteOne', async (q) => { query = q; return { deletedCount: 0 }; });
    const base = await start(t);
    const res = await fetch(`${base}/api/waste/${new mongoose.Types.ObjectId()}`, { method: 'DELETE' });
    assert.equal(res.status, 404);
    assert.equal(String(query.labId), String(labId));
    assert.equal(query.status, 'pending');
});
