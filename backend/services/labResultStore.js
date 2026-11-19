// Where a lab's result files are kept. The path tells the story on its own,
// so an archive stays readable without the system:
//
//   /uploads/results/L101/2026-11/V0006-4fK9xQ2m.pdf
//                    │    │       │     └ 8 random characters (not guessable)
//                    │    │       └ receipt number / sample code
//                    │    └ month (archive old months in one move)
//                    └ the lab's number (given when the lab is created)
const crypto = require('crypto');
const path = require('path');
const Lab = require('../models/Lab');
const Counter = require('../models/Counter');
const { r2Config } = require('./r2Service');

const ALPHABET = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

function randomId(length = 8) {
    let out = '';
    while (out.length < length) {
        for (const b of crypto.randomBytes(length * 2)) {
            // 248 = 4 × 62: keeps every character equally likely
            if (b < 248) out += ALPHABET[b % 62];
            if (out.length === length) break;
        }
    }
    return out;
}

/** The lab's number (101 for L101); older labs get one on first use. */
async function labNo(labOrId) {
    const id = labOrId?._id || labOrId;
    if (!id) throw new Error('A lab is required for result files');
    if (labOrId?.labNo) return labOrId.labNo;
    const lab = await Lab.findById(id).select('labNo');
    if (!lab) throw new Error('Lab not found');
    if (lab.labNo) return lab.labNo;
    const no = await Counter.next('labNo', 100);
    // Only set when still empty, so two uploads at once keep a single number.
    await Lab.collection.updateOne({ _id: lab._id, labNo: { $exists: false } }, { $set: { labNo: no } });
    const saved = await Lab.findById(id).select('labNo');
    if (labOrId && typeof labOrId === 'object' && labOrId._id) labOrId.labNo = saved.labNo;
    return saved.labNo;
}

/** "L101" */
async function labFolder(labOrId) {
    return `L${await labNo(labOrId)}`;
}

/** "2026-11" */
function monthOf(date = new Date()) {
    const d = date instanceof Date && !Number.isNaN(date.getTime()) ? date : new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

/** "uploads/results/L101/2026-11" */
async function resultsPath(labOrId, date = new Date()) {
    return `${r2Config.paths.results}/${await labFolder(labOrId)}/${monthOf(date)}`;
}

/** "V0006-4fK9xQ2m.pdf" — [ref] is the receipt number or sample code. */
function fileName(ref, originalName) {
    const safeRef = String(ref || '').replace(/[^A-Za-z0-9-]/g, '').slice(0, 40) || 'result';
    const name = String(originalName || '');
    // a bare extension (".heic") or a file name ("scan.heic")
    const ext = (/^\.[a-z0-9]+$/i.test(name) ? name : path.extname(name)).toLowerCase().replace(/[^.a-z0-9]/g, '') || '.pdf';
    return `${safeRef}-${randomId()}${ext}`;
}

module.exports = { randomId, labNo, labFolder, monthOf, resultsPath, fileName };
