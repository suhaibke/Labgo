function buildPublicPatient(input, hashedPassword, options = {}) {
    const patient = {
        name: input.name,
        phone: input.phone,
        city: input.city,
        gender: input.gender,
        birthDate: input.birthDate,
        password: hashedPassword,
        role: 'patient'
    };

    // Only set the key when a real email was given - leaving it out
    // entirely (rather than an empty/null value) is what keeps the
    // email field genuinely unset for phone-only registrations, so it
    // doesn't collide with other phone-only accounts on the unique index.
    if (input.email) {
        patient.email = input.email;
    }

    if (options.phoneVerified === true) {
        patient.phoneVerified = true;
    }

    return patient;
}

module.exports = { buildPublicPatient };
