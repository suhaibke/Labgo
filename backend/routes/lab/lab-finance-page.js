// Lab finance page: income, expenses, profit and unpaid walk-in orders.
const express = require('express');
const Order = require('../../models/Order');
const LabExpense = require('../../models/LabExpense');
const { summary } = require('../../services/labFinanceService');

const router = express.Router();

function langOf(req) {
    const currentLang = req.cookies?.lang
        || req.headers['accept-language']?.split(',')[0]?.split('-')[0]
        || 'ar';
    return {
        currentLang,
        direction: ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr',
        font: currentLang === 'ar' ? 'Cairo, sans-serif' : 'Inter, sans-serif',
    };
}

router.get('/finance', async (req, res) => {
    try {
        const data = await summary(req.lab._id, req.query.period);
        res.render('dashboard/lab-finance', {
            lab: req.lab,
            user: req.user,
            title: req.lab.name,
            ...langOf(req),
            activeSection: 'reports',
            categories: LabExpense.CATEGORIES,
            dataJson: JSON.stringify(data).replace(/</g, '\\u003c'),
        });
    } catch (error) {
        console.error('Finance page error:', error);
        res.status(500).render('error', { message: 'Error loading finance', error: null });
    }
});

router.get('/api/finance', async (req, res) => {
    try {
        res.json({ success: true, data: await summary(req.lab._id, req.query.period) });
    } catch (error) {
        console.error('Finance summary error:', error);
        res.status(500).json({ success: false, message: 'Error loading finance' });
    }
});

router.post('/api/finance/expenses', async (req, res) => {
    try {
        const { category, amount, date, note } = req.body || {};
        const value = Math.round(Number(amount));
        if (!Number.isFinite(value) || value <= 0) return res.status(400).json({ success: false, message: 'Enter an amount', code: 'amount' });
        const when = date ? new Date(date) : new Date();
        if (Number.isNaN(when.getTime())) return res.status(400).json({ success: false, message: 'Invalid date', code: 'date' });
        const expense = await LabExpense.create({
            labId: req.lab._id,
            category: LabExpense.CATEGORIES.includes(category) ? category : 'other',
            amount: value,
            date: when,
            note: String(note || '').trim().slice(0, 300),
            createdBy: req.user._id,
        });
        res.status(201).json({ success: true, data: expense });
    } catch (error) {
        console.error('Add expense error:', error);
        res.status(500).json({ success: false, message: 'Error saving the expense' });
    }
});

router.delete('/api/finance/expenses/:id', async (req, res) => {
    try {
        const result = await LabExpense.deleteOne({ _id: req.params.id, labId: req.lab._id });
        if (!result.deletedCount) return res.status(404).json({ success: false, message: 'Expense not found' });
        res.json({ success: true });
    } catch (error) {
        console.error('Delete expense error:', error);
        res.status(500).json({ success: false, message: 'Error deleting the expense' });
    }
});

// Collect the money for a walk-in order that was saved as "pay later".
router.post('/api/finance/orders/:orderId/paid', async (req, res) => {
    try {
        const order = await Order.findOne({ _id: req.params.orderId, labId: req.lab._id, orderType: 'walk_in' });
        if (!order) return res.status(404).json({ success: false, message: 'Order not found' });
        if (order.payment?.status !== 'paid') await order.markPaymentCollected(req.user._id);
        res.json({ success: true });
    } catch (error) {
        console.error('Mark paid error:', error);
        res.status(500).json({ success: false, message: 'Error saving the payment' });
    }
});

module.exports = router;
