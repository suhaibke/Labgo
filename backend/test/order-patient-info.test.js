const assert = require('node:assert/strict');
const test = require('node:test');

const {
    calculateAge,
    decorateOrderWithPatientInfo,
    getOrderPatientInfo
} = require('../helpers/order-patient-info');

test('calculateAge handles the day before and the day of a birthday in UTC', () => {
    assert.equal(calculateAge('2000-08-05', new Date('2026-08-04T23:59:59Z')), 25);
    assert.equal(calculateAge('2000-08-05', new Date('2026-08-05T00:00:00Z')), 26);
});

test('calculateAge returns null for missing, invalid, and future birth dates', () => {
    const asOf = new Date('2026-08-04T12:00:00Z');
    assert.equal(calculateAge(null, asOf), null);
    assert.equal(calculateAge('not-a-date', asOf), null);
    assert.equal(calculateAge('2027-01-01', asOf), null);
});

test('self orders use populated account demographics', () => {
    const patientInfo = getOrderPatientInfo({
        patientId: {
            _id: 'patient-1',
            name: 'Self Patient',
            phone: '07700000000',
            gender: 'female',
            birthDate: '2000-08-05'
        },
        beneficiary: { isForOtherPerson: false }
    }, new Date('2026-08-04T12:00:00Z'));

    assert.deepEqual(patientInfo, {
        id: 'patient-1',
        name: 'Self Patient',
        phone: '07700000000',
        gender: 'female',
        birthDate: '2000-08-05',
        age: 25,
        isBeneficiary: false
    });
});

test('other-person orders use beneficiary demographics instead of the purchaser', () => {
    const patientInfo = getOrderPatientInfo({
        patientId: {
            _id: 'purchaser-1',
            name: 'Purchaser',
            gender: 'male',
            birthDate: '1980-01-01'
        },
        beneficiary: {
            isForOtherPerson: true,
            name: 'Child Patient',
            phone: '07500000000',
            gender: 'female',
            birthDate: '2015-08-05'
        }
    }, new Date('2026-08-04T12:00:00Z'));

    assert.equal(patientInfo.name, 'Child Patient');
    assert.equal(patientInfo.gender, 'female');
    assert.equal(patientInfo.age, 10);
    assert.equal(patientInfo.isBeneficiary, true);
});

test('decorating an order preserves its fields and adds one stable patientInfo contract', () => {
    const decorated = decorateOrderWithPatientInfo({
        _id: 'order-1',
        qrCode: 'LAB-001',
        patientId: { _id: 'patient-1', name: 'Patient', gender: null, birthDate: null }
    }, new Date('2026-08-04T12:00:00Z'));

    assert.equal(decorated._id, 'order-1');
    assert.equal(decorated.qrCode, 'LAB-001');
    assert.deepEqual(decorated.patientInfo, {
        id: 'patient-1',
        name: 'Patient',
        phone: null,
        gender: null,
        birthDate: null,
        age: null,
        isBeneficiary: false
    });
});
