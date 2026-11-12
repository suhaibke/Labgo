const mongoose = require('mongoose');

// A lab's own running cost (rent, salaries, reagents...), entered on the
// Finance page. Income comes from orders, so it is not stored here.
const CATEGORIES = ['rent', 'salaries', 'reagents', 'electricity', 'transport', 'maintenance', 'other'];

const LabExpenseSchema = new mongoose.Schema({
    labId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lab', required: true, index: true },
    category: { type: String, enum: CATEGORIES, default: 'other' },
    amount: { type: Number, required: true, min: 0 },
    date: { type: Date, required: true, default: Date.now },
    note: { type: String, trim: true, default: '', maxlength: 300 },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });

LabExpenseSchema.index({ labId: 1, date: -1 });

const LabExpense = mongoose.model('LabExpense', LabExpenseSchema);
LabExpense.CATEGORIES = CATEGORIES;
module.exports = LabExpense;
