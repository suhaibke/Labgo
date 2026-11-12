const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const mongoose = require('mongoose');

const Order = require('../models/Order');
const LabExpense = require('../models/LabExpense');
const { summary, periodRange, labShare } = require('../services/labFinanceService');

const labId = new mongoose.Types.ObjectId();

function chain(value) {
    const q = { select() { return q; }, populate() { return q; }, sort() { return q; }, limit() { return q; }, lean: async () => value };
    return q;
}

test('the lab keeps its share after commission; walk-ins keep the whole total', () => {
    assert.equal(labShare({ pricing: { total: 50000 }, financials: { labAmount: 45000 } }), 45000);
    assert.equal(labShare({ pricing: { total: 50000 }, financials: { labAmount: 0 } }), 50000);
});

test('periods cover the right dates', () => {
    const now = new Date(2026, 10, 12, 15);
    const month = periodRange('month', now);
    assert.equal(month.from.getDate(), 1);
    assert.equal(month.to.getMonth(), 11);
    assert.equal(periodRange('lastMonth', now).from.getMonth(), 9);
    assert.equal(periodRange('year', now).unit, 'month');
});

test('summary adds income, expenses, profit and unpaid walk-ins', async (t) => {
    const today = new Date();
    let call = 0;
    t.mock.method(Order, 'find', () => chain(call++ === 0
        ? [
            { pricing: { total: 50000 }, financials: { labAmount: 45000 }, payment: { status: 'paid' }, createdAt: today },
            { pricing: { total: 30000 }, financials: { labAmount: 30000 }, payment: { status: 'pending' }, orderType: 'walk_in', createdAt: today },
        ]
        : [{ _id: 'o2', qrCode: 'LG-1', pricing: { total: 30000 }, financials: { labAmount: 30000 }, patientId: { name: 'Ali', phone: '0770' }, createdAt: today }]));
    t.mock.method(LabExpense, 'find', () => chain([
        { _id: 'e1', category: 'rent', amount: 20000, date: today, note: '' },
        { _id: 'e2', category: 'rent', amount: 5000, date: today, note: '' },
    ]));
    const s = await summary(labId, 'month');
    assert.equal(s.totals.income, 75000);
    assert.equal(s.totals.collected, 45000);
    assert.equal(s.totals.expenses, 25000);
    assert.equal(s.totals.profit, 50000);
    assert.equal(s.totals.debts, 30000);
    assert.equal(s.byCategory.rent, 25000);
    assert.equal(s.series.income[today.getDate() - 1], 75000);
    assert.equal(s.debts[0].name, 'Ali');
});

test('expenses need a positive amount and unknown categories become "other"', async (t) => {
    const created = [];
    t.mock.method(LabExpense, 'create', async (doc) => { created.push(doc); return doc; });
    const app = express();
    app.use(express.json());
    app.use((req, res, next) => { req.lab = { _id: labId }; req.user = { _id: 'u1' }; next(); });
    app.use(require('../routes/lab/lab-finance-page'));
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise((resolve) => server.close(resolve)));
    const post = (body) => fetch(`http://127.0.0.1:${server.address().port}/api/finance/expenses`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    assert.equal((await post({ amount: 0 })).status, 400);
    assert.equal((await post({ amount: 1500, category: 'bribes', date: '2026-11-12' })).status, 201);
    assert.equal(created[0].category, 'other');
    assert.equal(created[0].amount, 1500);
    assert.equal(String(created[0].labId), String(labId));
});
