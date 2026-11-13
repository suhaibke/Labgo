const mongoose = require('mongoose');

// Named sequences (e.g. patient ID numbers), incremented atomically.
const CounterSchema = new mongoose.Schema({
    _id: { type: String, required: true },
    seq: { type: Number, default: 0 },
}, { versionKey: false });

const Counter = mongoose.model('Counter', CounterSchema);

// Returns the next number of a sequence; the first value is start + 1.
Counter.next = async function next(name, start = 0) {
    await Counter.updateOne({ _id: name }, { $setOnInsert: { seq: start } }, { upsert: true });
    const doc = await Counter.findOneAndUpdate({ _id: name }, { $inc: { seq: 1 } }, { new: true });
    return doc.seq;
};

module.exports = Counter;
