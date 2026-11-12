const mongoose = require('mongoose');

// A medical waste collection request: the lab logs what is handed to the
// waste company and marks it collected when the driver takes it.
const TYPES = ['biohazard', 'sharps', 'chemical', 'general'];

const LabWasteSchema = new mongoose.Schema({
    labId: { type: mongoose.Schema.Types.ObjectId, ref: 'Lab', required: true, index: true },
    type: { type: String, enum: TYPES, required: true },
    weightKg: { type: Number, required: true, min: 0.01, max: 100000 },
    pickupDate: { type: Date, required: true },
    company: { type: String, trim: true, default: '', maxlength: 120 },
    notes: { type: String, trim: true, default: '', maxlength: 500 },
    status: { type: String, enum: ['pending', 'collected'], default: 'pending' },
    collectedAt: Date,
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });

LabWasteSchema.index({ labId: 1, pickupDate: -1 });

const LabWaste = mongoose.model('LabWaste', LabWasteSchema);
LabWaste.TYPES = TYPES;
module.exports = LabWaste;
