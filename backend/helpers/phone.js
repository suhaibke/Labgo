// Phone helpers shared by patient auth and lab reception (walk-in patients).
// Iraqi numbers are stored in several formats; try them all.

function getPhoneLoginCandidates(value) {
    const raw = value.trim();
    let digits = raw.replace(/\D/g, '');

    if (digits.startsWith('00964')) {
        digits = digits.slice(2);
    }

    const local = digits.startsWith('964') ? `0${digits.slice(3)}` : digits;
    const international = local.startsWith('0') ? `964${local.slice(1)}` : local;

    return [...new Set([raw, digits, local, international, `+${international}`].filter(Boolean))];
}

async function findByPhone(Model, candidates, extraQuery = {}) {
    for (const phone of candidates) {
        const record = await Model.findOne({ phone, ...extraQuery });
        if (record) return record;
    }
    return null;
}

module.exports = { getPhoneLoginCandidates, findByPhone };
