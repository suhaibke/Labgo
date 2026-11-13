// Lab finance: income from orders (the lab's share), the lab's own expenses,
// profit, and unpaid orders. Amounts are IQD.
const Order = require('../models/Order');
const LabExpense = require('../models/LabExpense');

const PERIODS = ['today', 'month', 'lastMonth', 'year'];

function periodRange(period, now = new Date()) {
    const y = now.getFullYear(), m = now.getMonth();
    switch (period) {
        case 'today': return { from: new Date(y, m, now.getDate()), to: new Date(y, m, now.getDate() + 1), unit: 'hour' };
        case 'lastMonth': return { from: new Date(y, m - 1, 1), to: new Date(y, m, 1), unit: 'day' };
        case 'year': return { from: new Date(y, 0, 1), to: new Date(y + 1, 0, 1), unit: 'month' };
        default: return { from: new Date(y, m, 1), to: new Date(y, m + 1, 1), unit: 'day' };
    }
}

// What the lab keeps from an order: its share after platform commission
// (walk-in orders keep everything).
function labShare(order) {
    const share = order.financials?.labAmount;
    if (typeof share === 'number' && share > 0) return share;
    return order.pricing?.total || 0;
}

function bucketKey(date, unit) {
    const d = new Date(date);
    if (unit === 'month') return d.getMonth();
    if (unit === 'hour') return d.getHours();
    return d.getDate() - 1;
}

function bucketCount(range) {
    if (range.unit === 'month') return 12;
    if (range.unit === 'hour') return 24;
    return Math.round((range.to - range.from) / 86400000);
}

async function summary(labId, period) {
    const range = periodRange(PERIODS.includes(period) ? period : 'month');
    const [orders, expenses, unpaid] = await Promise.all([
        Order.find({ labId, status: { $ne: 'cancelled' }, orderCategory: { $ne: 'prescription' }, createdAt: { $gte: range.from, $lt: range.to } })
            .select('pricing financials payment orderType createdAt').lean(),
        LabExpense.find({ labId, date: { $gte: range.from, $lt: range.to } }).sort({ date: -1 }).lean(),
        Order.find({ labId, status: { $ne: 'cancelled' }, 'payment.status': 'pending', orderType: 'walk_in' })
            .populate('patientId', 'name phone').sort({ createdAt: -1 }).limit(100).lean(),
    ]);

    const n = bucketCount(range);
    const incomeSeries = new Array(n).fill(0);
    const expenseSeries = new Array(n).fill(0);
    let income = 0, collected = 0;
    for (const o of orders) {
        const v = labShare(o);
        income += v;
        if (o.payment?.status === 'paid') collected += v;
        const k = bucketKey(o.createdAt, range.unit);
        if (k >= 0 && k < n) incomeSeries[k] += v;
    }
    const byCategory = {};
    let spent = 0;
    for (const e of expenses) {
        spent += e.amount;
        byCategory[e.category] = (byCategory[e.category] || 0) + e.amount;
        const k = bucketKey(e.date, range.unit);
        if (k >= 0 && k < n) expenseSeries[k] += e.amount;
    }
    const debts = unpaid.map((o) => ({
        _id: o._id,
        qrCode: o.qrCode,
        name: o.beneficiary?.isForOtherPerson ? o.beneficiary.name : (o.patientId?.name || ''),
        phone: o.patientId?.phone || '',
        amount: labShare(o),
        createdAt: o.createdAt,
    }));

    return {
        period: PERIODS.includes(period) ? period : 'month',
        unit: range.unit,
        from: range.from,
        totals: {
            income,
            collected,
            expenses: spent,
            profit: income - spent,
            debts: debts.reduce((s, d) => s + d.amount, 0),
            orders: orders.length,
        },
        series: { income: incomeSeries, expenses: expenseSeries },
        byCategory,
        expenses: expenses.map((e) => ({ _id: e._id, category: e.category, amount: e.amount, date: e.date, note: e.note })),
        debts,
    };
}

module.exports = { summary, periodRange, labShare, PERIODS };
