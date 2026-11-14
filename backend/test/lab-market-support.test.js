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
    // Store banners come from the admin's banner list (lab_store placement only).
    let bannerQuery = null;
    t.mock.method(require('../models/Banner'), 'find', (q) => { bannerQuery = q; return { sort() { return this; }, lean: async () => [{ _id: new mongoose.Types.ObjectId(), imageUrl: 'https://cdn.test/b.jpg' }] }; });
    t.mock.method(require('../models/AppSettings'), 'getSingleton', async () => ({ bannerDurationSeconds: 7 }));
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
    const listed = await (await fetch(`${base}/api/market`)).json();
    assert.deepEqual(query.$or, [{ approvalStatus: 'approved' }, { labId: lab._id }]);
    assert.deepEqual(bannerQuery, { isActive: true, placement: 'lab_store' });
    assert.equal(listed.data.banners[0].imageUrl, 'https://cdn.test/b.jpg');
    assert.equal(listed.data.bannerSeconds, 7);
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

test('buying a product takes stock, numbers the order and tells the seller', async (t) => {
    const MarketOrder = require('../models/MarketOrder');
    const seller = new mongoose.Types.ObjectId();
    const listing = { _id: new mongoose.Types.ObjectId(), kind: 'product', title: 'EDTA tubes', price: 20000, stock: 5, images: [], approvalStatus: 'approved', status: 'active', labId: { _id: seller, name: 'Al-Hayat' } };
    t.mock.method(MarketListing, 'findById', () => ({ populate: async () => listing }));
    const stockUpdates = [];
    t.mock.method(MarketListing, 'updateOne', async (q, u) => { stockUpdates.push([q, u]); return { modifiedCount: q.stock.$gte <= listing.stock ? 1 : 0 }; });
    t.mock.method(Counter, 'next', async () => 7001);
    const created = [];
    t.mock.method(MarketOrder, 'create', async (doc) => { created.push(doc); return { ...doc, _id: new mongoose.Types.ObjectId(), status: 'new', createdAt: new Date() }; });
    const notes = [];
    t.mock.method(labNotify, 'notifyLab', async (id, n) => { notes.push([String(id), n]); });
    const base = await start(t);
    const post = (body) => fetch(`${base}/api/market/${listing._id}/order`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    assert.equal((await post({ quantity: 2, address: 'Mosul' })).status, 400, 'phone is required');
    assert.equal((await post({ quantity: 2, phone: '07701234567' })).status, 400, 'address is required');
    assert.equal((await post({ quantity: 9, phone: '07701234567', address: 'Mosul' })).status, 409, 'not enough stock');
    const ok = await post({ quantity: 2, phone: '07701234567', address: 'Mosul' });
    assert.equal(ok.status, 201);
    const body = await ok.json();
    assert.equal(body.data.orderNo, 7001);
    assert.equal(body.data.total, 40000);
    assert.equal(body.data.role, 'buyer');
    assert.equal(created[0].kind, 'purchase');
    assert.deepEqual(stockUpdates.at(-1)[1], { $inc: { stock: -2 } });
    assert.equal(notes[0][0], String(seller));
    assert.equal(notes[0][1].data.type, 'store_order');
});

test('you cannot order your own listing or an auction', async (t) => {
    const mine = { _id: new mongoose.Types.ObjectId(), kind: 'product', title: 'X', price: 1, stock: 1, approvalStatus: 'approved', status: 'active', labId: { _id: lab._id, name: 'me' } };
    const auction = { ...mine, _id: new mongoose.Types.ObjectId(), kind: 'auction', labId: { _id: new mongoose.Types.ObjectId() } };
    t.mock.method(MarketListing, 'findById', (id) => ({ populate: async () => (String(id) === String(mine._id) ? mine : auction) }));
    const base = await start(t);
    const post = (id) => fetch(`${base}/api/market/${id}/order`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ phone: '07701234567', address: 'a' }) });
    assert.equal((await (await post(mine._id)).json()).code, 'own');
    assert.equal((await (await post(auction._id)).json()).code, 'auction');
});

test('order steps: the seller moves it forward, the buyer may only cancel a new order', () => {
    const { allowedMove } = require('../routes/lab/market-support');
    const seller = new mongoose.Types.ObjectId(), buyer = new mongoose.Types.ObjectId();
    const o = (status) => ({ sellerLabId: seller, buyerLabId: buyer, status });
    assert.equal(allowedMove(o('new'), seller, 'preparing'), true);
    assert.equal(allowedMove(o('new'), seller, 'delivered'), false);
    assert.equal(allowedMove(o('preparing'), seller, 'shipped'), true);
    assert.equal(allowedMove(o('shipped'), seller, 'cancelled'), false);
    assert.equal(allowedMove(o('new'), buyer, 'cancelled'), true);
    assert.equal(allowedMove(o('preparing'), buyer, 'cancelled'), false);
    assert.equal(allowedMove(o('new'), buyer, 'preparing'), false);
});
