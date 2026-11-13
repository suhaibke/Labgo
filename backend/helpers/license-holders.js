// Licence holders shown in the report header: at most 6, short plain text.
function cleanLicenseHolders(list) {
    if (!Array.isArray(list)) return [];
    const clip = (v, n) => String(v || '').replace(/\s+/g, ' ').trim().slice(0, n);
    return list
        .map((h) => ({ title: clip(h && h.title, 20), name: clip(h && h.name, 80), specialty: clip(h && h.specialty, 60) }))
        .filter((h) => h.name)
        .slice(0, 6);
}

module.exports = { cleanLicenseHolders };
