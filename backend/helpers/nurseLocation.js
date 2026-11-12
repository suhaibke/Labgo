/** Best available map point for a nurse: live GPS, else saved default. */
function pickNurseMapLocation(nurse) {
    if (!nurse) return null;
    const live = nurse.currentLocation;
    if (Number.isFinite(Number(live?.latitude)) && Number.isFinite(Number(live?.longitude))) {
        return {
            latitude: Number(live.latitude),
            longitude: Number(live.longitude),
            updatedAt: live.updatedAt || new Date(),
        };
    }
    const coords = nurse.defaultLocation?.coordinates;
    if (Number.isFinite(Number(coords?.latitude)) && Number.isFinite(Number(coords?.longitude))) {
        return {
            latitude: Number(coords.latitude),
            longitude: Number(coords.longitude),
            updatedAt: new Date(),
        };
    }
    return null;
}

/** Ensure the order JSON always exposes nurseMapLocation for the tracking map. */
function attachNurseMapLocation(order) {
    if (!order) return order;
    const plain = typeof order.toObject === 'function' ? order.toObject() : order;
    const existing = plain.nurseMapLocation;
    if (Number.isFinite(Number(existing?.latitude)) && Number.isFinite(Number(existing?.longitude))) {
        return plain;
    }
    const nurse = plain.nurseId && typeof plain.nurseId === 'object' ? plain.nurseId : null;
    const picked = pickNurseMapLocation(nurse);
    if (picked) plain.nurseMapLocation = picked;
    return plain;
}

module.exports = { pickNurseMapLocation, attachNurseMapLocation };
