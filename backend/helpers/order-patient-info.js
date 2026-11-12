function normalizeDateValue(value) {
    if (value === null || value === undefined || value === '') return null;
    const date = value instanceof Date ? value : new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
}

function calculateAge(birthDate, asOf = new Date()) {
    const birth = normalizeDateValue(birthDate);
    const reference = normalizeDateValue(asOf);
    if (!birth || !reference || birth > reference) return null;

    let age = reference.getUTCFullYear() - birth.getUTCFullYear();
    const birthdayHasPassed = reference.getUTCMonth() > birth.getUTCMonth()
        || (reference.getUTCMonth() === birth.getUTCMonth()
            && reference.getUTCDate() >= birth.getUTCDate());

    if (!birthdayHasPassed) age -= 1;
    return age >= 0 ? age : null;
}

function idToString(value) {
    if (value === null || value === undefined) return null;
    if (typeof value === 'string') return value;
    if (typeof value.toString === 'function') return value.toString();
    return null;
}

function getOrderPatientInfo(order, asOf = new Date()) {
    const beneficiary = order?.beneficiary;
    const isBeneficiary = beneficiary?.isForOtherPerson === true;
    const source = isBeneficiary ? beneficiary : (order?.patientId || {});
    const rawBirthDate = source?.birthDate ?? null;

    return {
        id: isBeneficiary ? null : idToString(source?._id ?? source?.id),
        name: source?.name || 'Unknown',
        phone: source?.phone || null,
        gender: source?.gender || null,
        birthDate: rawBirthDate instanceof Date ? rawBirthDate.toISOString() : rawBirthDate,
        age: calculateAge(rawBirthDate, asOf),
        isBeneficiary
    };
}

function decorateOrderWithPatientInfo(order, asOf = new Date()) {
    const plainOrder = typeof order?.toObject === 'function'
        ? order.toObject({ virtuals: true })
        : { ...order };

    return {
        ...plainOrder,
        patientInfo: getOrderPatientInfo(plainOrder, asOf)
    };
}

module.exports = {
    calculateAge,
    decorateOrderWithPatientInfo,
    getOrderPatientInfo
};
