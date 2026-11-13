const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const mongoose = require('mongoose');

const MarketListing = require('../models/MarketListing');
const SupportTicket = require('../models/SupportTicket');
const Counter = require('../models/Counter');
const market = require('../services/marketService');
const labNotify = require('../services/labNotify');

const lab = { _id: new mongoose.Types.ObjectId(), name: 'LabGo Mosul' };

async function start(t) {
    const app = express();
    app.use(express.json());
    app.use((req, res, next) => { req.lab = lab; req.user = { _id: new mongoose.Types.ObjectId() }; next(); });
    app.use(require('../routes/lab/market-support'));
    const server = http.createServer(app);
    await new Promise((r) => server.listen(0, '127.0.0.1', r));
    t.after(() => new Promise((r) => server.close(r)));
    return `http://127.0.0.1:${server.address().port}`;
}

test('a new listing waits for the admin; others see only approved ones', async (t) => {
    const created = [];
    t.mock.method(MarketListing, 'create', async (doc) => { created.push(doc); return { ...doc, _id: new mongoose.Types.ObjectId(), approvalStatus: 'pending' }; });
    let query = null;
    t.mock.method(MarketListing, 'find', (q) => { query = q; return { sort() { return this; }, limit() { return this; }, populate() { return this; }, lean: async () => [] }; });
    t.mock.method(market, 'settleDue', async () => {});
    const base = await start(t);
    const post = (fields) => {
        const fd = new FormData();
        for (const [k, v] of Object.entries(fields)) fd.append(k, v);
        return fetch(`${base}/api/market`, { method: 'POST', body: fd });
    };
    assert.equal((await post({ kind: 'product', title: 'Centrifuge', price: '850000' })).status, 400, 'a product needs a quantity');
    const res = await post({ kind: 'auction', title: 'Microscope', price: '500,000', days: '5' });
    assert.equal(res.status, 201);
    assert.equal((await res.json()).data.approvalStatus, 'pending');
    assert.equal(created[0].durationDays, 5);
    await fetch(`${base}/api/market`);
    assert.deepEqual(query.$or, [{ approvalStatus: 'approved' }, { labId: lab._id }]);
});

test('an ended auction goes to the highest bidder and both labs are told', async (t) => {
    const winner = new mongoose.Types.ObjectId();
    const sent = [];
    t.mock.method(labNotify, 'notifyLab', async (labId, n) => { sent.push([String(labId), n.data.type]); });
    t.mock.method(MarketListing, 'updateOne', async () => ({ modifiedCount: 1 }));
    const l = { _id: new mongoose.Types.ObjectId(), kind: 'auction', title: 'Microscope', labId: lab._id, endsAt: new Date(Date.now() - 1000), settledAt: null,
        bids: [{ labId: new mongoose.Types.ObjectId(), labName: 'A', amount: 600000 }, { labId: winner, labName: 'B', amount: 720000 }] };
    await market.settle(l);
    assert.equal(String(l.winnerLabId), String(winner));
    assert.deepEqual(sent, [[String(winner), 'auction_won'], [String(lab._id), 'auction_ended']]);
});

test('a support message gets a ticket number', async (t) => {
    t.mock.method(Counter, 'next', async () => 5001);
    t.mock.method(SupportTicket, 'create', async (doc) => ({ ...doc, _id: new mongoose.Types.ObjectId() }));
    const base = await start(t);
    const fd = new FormData();
    fd.append('type', 'bug');
    fd.append('message', 'The print button does nothing');
    const res = await fetch(`${base}/api/support`, { method: 'POST', body: fd });
    assert.equal(res.status, 201);
    assert.equal((await res.json()).data.ticketNo, 5001);
    const empty = new FormData();
    empty.append('message', ' ');
    assert.equal((await fetch(`${base}/api/support`, { method: 'POST', body: empty })).status, 400);
});
