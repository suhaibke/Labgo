const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const Order = require('../models/Order');
const receipt = require('../services/receiptLinkService');

async function start(t) {
    const app = express();
    app.use(require('../routes/receipt-result'));
    const server = http.createServer(app);
    await new Promise((r) => server.listen(0, '127.0.0.1', r));
    t.after(() => new Promise((r) => server.close(r)));
    return `http://127.0.0.1:${server.address().port}`;
}

test('a code is the order number plus six random characters', () => {
    const code = receipt.newCode({ receiptNo: 1 });
    assert.match(code, /^V0001-[A-HJ-NP-Za-km-z2-9]{6}$/);
    assert.match(code, receipt.CODE_RE);
    assert.equal(receipt.shortLink('https://labgo.test/', code), `https://labgo.test/r/${code}`);
    assert.notEqual(receipt.newCode({ receiptNo: 1 }), receipt.newCode({ receiptNo: 1 }));
    // orders without a receipt number: eight random characters
    assert.match(receipt.newCode({}), /^[A-HJ-NP-Za-km-z2-9]{8}$/);
});

test('the order number alone is never enough, and v/V are the same', () => {
    assert.equal(receipt.normalizeCode('V0001'), null);
    assert.equal(receipt.normalizeCode('v0001'), null);
    assert.equal(receipt.normalizeCode('v0001-k7Qm2x'), 'V0001-k7Qm2x');
    assert.equal(receipt.normalizeCode('V0001-k7Qm2x'), 'V0001-k7Qm2x');
    assert.equal(receipt.normalizeCode('V0001-k7Q'), null);
});

test('the short link opens the approved report, waits otherwise, and rejects unknown codes', async (t) => {
    const orders = {
        'V0003-AAAAAA': { receiptNo: 3, labId: { name: 'Lab' }, results: { entryStatus: 'approved', reportUrl: 'https://cdn.test/r.pdf' } },
        BBBBBBBB: { receiptNo: 4, labId: { name: 'Lab', phone: '0770' }, results: { entryStatus: 'draft' } },
    };
    let asked = null;
    t.mock.method(Order, 'findOne', (q) => { asked = q; return { select() { return this; }, populate: async () => orders[q.resultCode] || null }; });
    const base = await start(t);
    const ok = await fetch(`${base}/r/v0003-AAAAAA`, { redirect: 'manual' });
    assert.equal(ok.status, 302);
    assert.equal(ok.headers.get('location'), 'https://cdn.test/r.pdf');
    assert.deepEqual(asked, { resultCode: 'V0003-AAAAAA' });
    const wait = await fetch(`${base}/r/BBBBBBBB`);
    assert.equal(wait.status, 200);
    assert.match(await wait.text(), /V0004/);
    assert.equal((await fetch(`${base}/r/CCCCCCCC`)).status, 404);
    asked = null;
    assert.equal((await fetch(`${base}/r/V0003`)).status, 404, 'the bare order number is not a link');
    assert.equal(asked, null);
});
