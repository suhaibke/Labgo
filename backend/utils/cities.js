// Iraqi governorates - mirrors lib/src/utils/cities.dart on the Flutter
// side. `id` is a stable ASCII key safe to use in FCM topic names (topic
// names only allow [A-Za-z0-9-_.~%]).
const IRAQI_CITIES = [
    { id: 'baghdad', nameAr: 'بغداد' },
    { id: 'basra', nameAr: 'البصرة' },
    { id: 'ninawa', nameAr: 'نينوى' },
    { id: 'anbar', nameAr: 'الأنبار' },
    { id: 'kirkuk', nameAr: 'كركوك' },
    { id: 'salahadin', nameAr: 'صلاح الدين' },
    { id: 'diyala', nameAr: 'ديالى' },
    { id: 'babel', nameAr: 'بابل' },
    { id: 'karbala', nameAr: 'كربلاء' },
    { id: 'najaf', nameAr: 'النجف' },
    { id: 'qadisiyah', nameAr: 'القادسية' },
    { id: 'muthanna', nameAr: 'المثنى' },
    { id: 'wasit', nameAr: 'واسط' },
    { id: 'thiqar', nameAr: 'ذي قار' },
    { id: 'maysan', nameAr: 'ميسان' },
    { id: 'erbil', nameAr: 'أربيل' },
    { id: 'sulaymaniyah', nameAr: 'السليمانية' },
    { id: 'duhok', nameAr: 'دهوك' },
];

const AR_NAME_TO_ID = new Map(IRAQI_CITIES.map((c) => [c.nameAr, c.id]));

/**
 * Turns a stored (Arabic) governorate name into the stable ASCII key used
 * for FCM topic names (e.g. 'nurse_city_kirkuk', 'patient_city_baghdad').
 *
 * Previously this was done with `.replace(/[^a-z0-9_]/g, '')`, which
 * strips every Arabic character and silently collapsed every governorate
 * into the same empty-suffixed topic - so every nurse/patient ended up on
 * one shared topic and received notifications meant for other cities.
 */
function cityToTopicKey(cityName) {
    if (!cityName) return 'unknown';
    const known = AR_NAME_TO_ID.get(cityName.trim());
    if (known) return known;

    // Defensive fallback for a city name that doesn't match the known list
    // (e.g. legacy/free-text data) - still ASCII-safe, still unique per
    // distinct input, just not a pretty name.
    return cityName
        .trim()
        .split('')
        .reduce((hash, ch) => ((hash << 5) - hash + ch.charCodeAt(0)) | 0, 0)
        .toString(36)
        .replace('-', 'n');
}

module.exports = { IRAQI_CITIES, cityToTopicKey };
