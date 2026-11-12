class ExternalTransferError extends Error {
    constructor(message, statusCode) {
        super(message);
        this.name = 'ExternalTransferError';
        this.statusCode = statusCode;
    }
}

function cleanOptionalText(value) {
    if (value === null || value === undefined) return undefined;
    const cleaned = String(value).trim();
    return cleaned || undefined;
}

function parseOptionalDate(value) {
    if (!value) return undefined;
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) {
        throw new ExternalTransferError('Expected result date is invalid', 400);
    }
    return parsed;
}

// Common fields shared by both the order-linked and manual creation paths.
function buildCommonFields(input, options = {}) {
    const labName = cleanOptionalText(input?.labName);
    if (!labName) {
        throw new ExternalTransferError('External lab name is required', 400);
    }

    const fields = {
        externalLab: { name: labName },
        status: 'sent',
        sentAt: options.now instanceof Date ? options.now : new Date(),
    };

    const externalLabFields = {
        contactName: cleanOptionalText(input.contactName),
        phone: cleanOptionalText(input.phone),
        address: cleanOptionalText(input.address),
    };
    Object.entries(externalLabFields).forEach(([key, value]) => {
        if (value !== undefined) fields.externalLab[key] = value;
    });

    const expectedResultAt = parseOptionalDate(input.expectedResultAt);
    if (expectedResultAt) fields.expectedResultAt = expectedResultAt;

    const referenceNumber = cleanOptionalText(input.referenceNumber);
    if (referenceNumber) fields.referenceNumber = referenceNumber;

    const notes = cleanOptionalText(input.notes);
    if (notes) fields.notes = notes;

    if (options.userId) fields.createdBy = options.userId;
    return fields;
}

// Resolves the tests picked in the transfer form against the order's own
// test list. Falls back to every test on the order when none were picked.
function resolveOrderTests(order, testIds) {
    const orderTests = order?.tests || [];
    const requestedIds = Array.isArray(testIds)
        ? testIds.map((id) => String(id)).filter(Boolean)
        : [];

    const source = requestedIds.length
        ? orderTests.filter((t) => requestedIds.includes(String(t.testId)))
        : orderTests;

    if (requestedIds.length && !source.length) {
        throw new ExternalTransferError('None of the selected tests belong to this order', 400);
    }

    return source.map((t) => ({ testId: t.testId, testName: t.testName }));
}

module.exports = {
    ExternalTransferError,
    buildCommonFields,
    resolveOrderTests,
    cleanOptionalText,
};
