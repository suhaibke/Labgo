// Picks the normal range for a patient and flags a value High/Low/Normal.
// Same rules as the lab app: match gender (or Both) and age, then fall back
// to age only, then to the first range.

const DAYS = { Y: 365, M: 30, D: 1 };

function toDays(n, unit) {
    return (Number(n) || 0) * (DAYS[unit] || 365);
}

function pickRange(ranges, patient = {}) {
    if (!Array.isArray(ranges) || ranges.length === 0) return null;
    // Prefer the exact birth date (babies' ranges are in months/days).
    const birth = patient.birthDate ? new Date(patient.birthDate) : null;
    const hasAge = patient.age !== null && patient.age !== undefined && patient.age !== '';
    let ageDays = null;
    if (birth && !Number.isNaN(birth.getTime())) ageDays = Math.max(0, (Date.now() - birth.getTime()) / 86400000);
    else if (hasAge) ageDays = toDays(patient.age, patient.ageUnit || 'Y');
    const gender = String(patient.gender || '').toLowerCase() === 'female' ? 'Female' : 'Male';
    const inAge = (r) => ageDays === null || (ageDays >= toDays(r.ageFrom, r.ageUnit) && ageDays <= toDays(r.ageTo, r.ageUnit));
    return ranges.find((r) => (r.gender === 'Both' || r.gender === gender) && inAge(r))
        || ranges.find(inAge)
        || ranges[0];
}

function classify(value, min, max) {
    const text = String(value ?? '').trim();
    if (!text) return '';
    const v = Number(text);
    if (!Number.isFinite(v)) return '';
    if (min !== null && min !== undefined && v < min) return 'low';
    if (max !== null && max !== undefined && v > max) return 'high';
    if ((min === null || min === undefined) && (max === null || max === undefined)) return '';
    return 'normal';
}

module.exports = { pickRange, classify };
