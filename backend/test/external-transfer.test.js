const assert = require('node:assert/strict');
const test = require('node:test');

const ExternalTransfer = require('../models/ExternalTransfer');
const {
    ExternalTransferError,
    buildCommonFields,
    resolveOrderTests,
} = require('../services/externalTransferService');

const sentAt = new Date('2026-08-04T09:30:00Z');

test('buildCommonFields trims the external lab snapshot and keeps optional fields out when blank', () => {
    const fields = buildCommonFields({
        labName: '  Al-Nahrain Reference Lab  ',
        contactName: ' Dr. Sara ',
        phone: ' 07701234567 ',
        address: ' Baghdad ',
        referenceNumber: ' REF-42 ',
        expectedResultAt: '2026-08-07',
        notes: ' Keep refrigerated ',
    }, { userId: 'lab-user-1', now: sentAt });

    assert.deepEqual(fields, {
        externalLab: {
            name: 'Al-Nahrain Reference Lab',
            contactName: 'Dr. Sara',
            phone: '07701234567',
            address: 'Baghdad',
        },
        status: 'sent',
        sentAt,
        expectedResultAt: new Date('2026-08-07T00:00:00.000Z'),
        referenceNumber: 'REF-42',
        notes: 'Keep refrigerated',
        createdBy: 'lab-user-1',
    });
});

test('buildCommonFields requires a lab name', () => {
    assert.throws(
        () => buildCommonFields({ labName: '   ' }, { now: sentAt }),
        (error) => error instanceof ExternalTransferError && error.statusCode === 400
    );
});

test('buildCommonFields rejects an invalid expected-result date', () => {
    assert.throws(
        () => buildCommonFields({ labName: 'Lab', expectedResultAt: 'not-a-date' }, { now: sentAt }),
        (error) => error instanceof ExternalTransferError && error.statusCode === 400
    );
});

test('resolveOrderTests defaults to every test on the order when none are picked', () => {
    const order = {
        tests: [
            { testId: 'a1', testName: 'CBC' },
            { testId: 'a2', testName: 'Thyroid' },
        ],
    };

    assert.deepEqual(resolveOrderTests(order, []), [
        { testId: 'a1', testName: 'CBC' },
        { testId: 'a2', testName: 'Thyroid' },
    ]);
});

test('resolveOrderTests narrows to the picked test ids', () => {
    const order = {
        tests: [
            { testId: 'a1', testName: 'CBC' },
            { testId: 'a2', testName: 'Thyroid' },
        ],
    };

    assert.deepEqual(resolveOrderTests(order, ['a2']), [{ testId: 'a2', testName: 'Thyroid' }]);
});

test('resolveOrderTests rejects test ids that do not belong to the order', () => {
    const order = { tests: [{ testId: 'a1', testName: 'CBC' }] };

    assert.throws(
        () => resolveOrderTests(order, ['not-on-this-order']),
        (error) => error instanceof ExternalTransferError && error.statusCode === 400
    );
});

test('ExternalTransfer.generateSampleCode returns a distinct EXT-prefixed code each time', () => {
    const first = ExternalTransfer.generateSampleCode();
    const second = ExternalTransfer.generateSampleCode();
    assert.match(first, /^EXT-[0-9A-Z]+-[0-9A-Z]+$/);
    assert.notEqual(first, second);
});

test('ExternalTransfer schema allows a manual entry with no linked order', () => {
    const doc = new ExternalTransfer({
        labId: '64b000000000000000000001',
        sampleCode: 'EXT-TEST-1',
        patientName: 'Walk-in Patient',
        testsDescription: 'CBC, Thyroid panel',
        externalLab: { name: 'Reference Lab' },
        sentAt,
    });

    const validationError = doc.validateSync();
    assert.equal(validationError, undefined);
    assert.equal(doc.orderId, null);
});

test('ExternalTransfer schema requires a patient name', () => {
    const doc = new ExternalTransfer({
        labId: '64b000000000000000000001',
        sampleCode: 'EXT-TEST-2',
        externalLab: { name: 'Reference Lab' },
        sentAt,
    });

    const validationError = doc.validateSync();
    assert.ok(validationError);
    assert.ok(validationError.errors.patientName);
});
