// Live sync between the lab app and the web dashboard (services/labLive.js).
const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const labLive = require('../services/labLive');

// A tiny lab server: the real tracker and stream behind a stand-in for the lab
// auth middleware (the real one sets the same req fields from the JWT).
function server() {
    const app = express();
    app.use(express.json());
    app.use((req, res, next) => {
        const who = req.header('X-Test-User') || 'owner:A';
        const [role, lab] = who.split(':');
        req.lab = { _id: `lab${lab}` };
        req.user = { _id: `${role}${lab}` };
        req.isLabOwner = role === 'owner';
        req.labPermissions = role === 'owner' ? [] : role === 'reception' ? ['patients'] : ['finance'];
        next();
    });
    app.get('/api/live', labLive.stream);
    app.use(labLive.track);
    app.put('/api/app/tests', (req, res) => res.json({ success: true }));
    app.patch('/api/app/orders/:id/patient', (req, res) => res.json({ success: true }));
    app.post('/api/finance/expenses', (req, res) => res.json({ success: true }));
    app.put('/api/staff/:id', (req, res) => res.json({ success: true }));
    app.put('/api/app/broken', (req, res) => res.status(400).json({ success: false }));
    return new Promise((resolve) => {
        const s = app.listen(0, () => resolve(s));
    });
}

/** Opens the stream and collects its events until close(). */
function listen(port, user, lastId) {
    const events = [];
    let req;
    const ready = new Promise((resolve) => {
        req = http.get({ port, path: '/api/live', headers: { 'X-Test-User': user, ...(lastId ? { 'Last-Event-ID': lastId } : {}) } }, (res) => {
            let buf = '';
            res.on('data', (c) => {
                buf += c;
                let i;
                while ((i = buf.indexOf('\n\n')) >= 0) {
                    const block = buf.slice(0, i);
                    buf = buf.slice(i + 2);
                    const ev = /^event: (.*)$/m.exec(block)?.[1];
                    const id = /^id: (.*)$/m.exec(block)?.[1];
                    const data = /^data: (.*)$/m.exec(block)?.[1];
                    if (ev) events.push({ ev, id, data: data ? JSON.parse(data) : null });
                    if (ev === 'hello') resolve();
                }
            });
            res.on('end', () => events.push({ ev: 'closed' }));
        });
    });
    return { events, ready, close: () => req.destroy() };
}

const call = (port, method, path, user = 'owner:A', headers = {}) =>
    new Promise((resolve) => {
        const r = http.request({ port, method, path, headers: { 'X-Test-User': user, 'Content-Type': 'application/json', ...headers } }, (res) => {
            res.resume();
            res.on('end', resolve);
        });
        r.end('{}');
    });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

test('a change from the app reaches the same lab only, with its source and kind', async () => {
    const s = await server();
    const { port } = s.address();
    const a = listen(port, 'owner:A'), b = listen(port, 'owner:B');
    await Promise.all([a.ready, b.ready]);
    await call(port, 'PUT', '/api/app/tests', 'owner:A', { Authorization: 'Bearer x' });
    await wait(50);
    const got = a.events.filter((e) => e.ev === 'change');
    assert.equal(got.length, 1);
    assert.equal(got[0].data.kind, 'tests');
    assert.equal(got[0].data.source, 'app');
    assert.equal(b.events.filter((e) => e.ev === 'change').length, 0, 'another lab hears nothing');
    a.close(); b.close(); s.close();
});

test('a failed request publishes nothing; the web tab id comes back so a tab can skip its own save', async () => {
    const s = await server();
    const { port } = s.address();
    const a = listen(port, 'owner:C');
    await a.ready;
    await call(port, 'PUT', '/api/app/broken', 'owner:C');
    await call(port, 'PUT', '/api/app/tests', 'owner:C', { 'X-Live-Client': 'tab1' });
    await wait(50);
    const got = a.events.filter((e) => e.ev === 'change');
    assert.equal(got.length, 1);
    assert.equal(got[0].data.source, 'web');
    assert.equal(got[0].data.client, 'tab1');
    a.close(); s.close();
});

test('staff hear only what their role may open; a staff change closes every stream to re-check access', async () => {
    const s = await server();
    const { port } = s.address();
    const r = listen(port, 'reception:D');
    await r.ready;
    await call(port, 'PUT', '/api/app/tests', 'owner:D'); // tests: not a receptionist's
    await call(port, 'POST', '/api/finance/expenses', 'owner:D'); // finance: not theirs
    await call(port, 'PATCH', '/api/app/orders/1/patient', 'owner:D'); // patients: theirs
    await call(port, 'PUT', '/api/staff/9', 'owner:D'); // roles changed
    await wait(80);
    const kinds = r.events.filter((e) => e.ev === 'change').map((e) => e.data.kind);
    assert.deepEqual(kinds, ['orders', 'staff']);
    assert.ok(r.events.some((e) => e.ev === 'reauth'));
    assert.ok(r.events.some((e) => e.ev === 'closed'));
    r.close(); s.close();
});

test('reconnecting replays what was missed, or asks for a full refresh', async () => {
    const s = await server();
    const { port } = s.address();
    const first = listen(port, 'owner:E');
    await first.ready;
    await call(port, 'PUT', '/api/app/tests', 'owner:E');
    await wait(40);
    const lastId = first.events.find((e) => e.ev === 'change').id;
    first.close();
    await call(port, 'PUT', '/api/app/tests', 'owner:E');
    await call(port, 'PATCH', '/api/app/orders/1/patient', 'owner:E');
    const again = listen(port, 'owner:E', lastId);
    await again.ready;
    await wait(40);
    assert.deepEqual(again.events.filter((e) => e.ev === 'change').map((e) => e.data.kind), ['tests', 'orders']);
    again.close();
    const stale = listen(port, 'owner:E', 'oldboot.1');
    await stale.ready;
    await wait(40);
    assert.ok(stale.events.some((e) => e.ev === 'resync'), 'a previous server run cannot be replayed');
    stale.close(); s.close();
});

test('kindOf maps the app and web paths to the same kinds', () => {
    assert.equal(labLive.kindOf('/api/app/tests'), 'tests');
    assert.equal(labLive.kindOf('/api/tests/123'), 'tests');
    assert.equal(labLive.kindOf('/api/app/packages'), 'packages');
    assert.equal(labLive.kindOf('/api/packages/1'), 'packages');
    assert.equal(labLive.kindOf('/api/staff/roles'), 'staff');
    assert.equal(labLive.kindOf('/api/orders/1/results/approve'), 'results');
    assert.equal(labLive.kindOf('/api/app/transfers/1/results'), 'results');
    assert.equal(labLive.kindOf('/api/app/orders/1/pay'), 'orders');
    assert.equal(labLive.kindOf('/api/finance/expenses'), 'finance');
    assert.equal(labLive.kindOf('/api/app/lab'), 'lab');
});
