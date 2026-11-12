const mongoose = require('mongoose');

// Single-document collection for small app-wide settings that don't belong
// to any other model (e.g. the home page banner rotation speed). Add new
// fields here rather than creating a new collection for every setting.
const AppSettingsSchema = new mongoose.Schema({
    bannerDurationSeconds: {
        type: Number,
        default: 5,
        min: 2,
        max: 30,
    },
}, { timestamps: true });

AppSettingsSchema.statics.getSingleton = async function () {
    let doc = await this.findOne();
    if (!doc) {
        doc = await this.create({});
    }
    return doc;
};

module.exports = mongoose.model('AppSettings', AppSettingsSchema);
