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

test('codes are 8 unambiguous characters and make a short link', () => {
    const code = receipt.newCode();
    assert.match(code, receipt.CODE_RE);
    assert.doesNotMatch(code, /[IOl01]/);
    assert.equal(receipt.shortLink('https://labgo.test/', code), `https://labgo.test/r/${code}`);
    assert.notEqual(receipt.newCode(), receipt.newCode());
});

test('the short link opens the approved report, waits otherwise, and rejects unknown codes', async (t) => {
    const orders = {
        AAAAAAAA: { receiptNo: 3, labId: { name: 'Lab' }, results: { entryStatus: 'approved', reportUrl: 'https://cdn.test/r.pdf' } },
        BBBBBBBB: { receiptNo: 4, labId: { name: 'Lab', phone: '0770' }, results: { entryStatus: 'draft' } },
    };
    let asked = null;
    t.mock.method(Order, 'findOne', (q) => { asked = q; return { select() { return this; }, populate: async () => orders[q.resultCode] || null }; });
    const base = await start(t);
    const ok = await fetch(`${base}/r/AAAAAAAA`, { redirect: 'manual' });
    assert.equal(ok.status, 302);
    assert.equal(ok.headers.get('location'), 'https://cdn.test/r.pdf');
    assert.deepEqual(asked, { resultCode: 'AAAAAAAA' });
    const wait = await fetch(`${base}/r/BBBBBBBB`);
    assert.equal(wait.status, 200);
    assert.match(await wait.text(), /V0004/);
    assert.equal((await fetch(`${base}/r/CCCCCCCC`)).status, 404);
    asked = null;
    assert.equal((await fetch(`${base}/r/short`)).status, 404, 'not a code: no lookup');
    assert.equal(asked, null);
});
