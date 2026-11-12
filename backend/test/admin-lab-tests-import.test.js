const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const XLSX = require('xlsx');

const Lab = require('../models/Lab');
const User = require('../models/User');
const labRoutes = require('../routes/admin/labs');

const adminId = '507f1f77bcf86cd799439011';
const ownerId = '507f191e810c19729de860ea';
const labId = '6ae4c754d9df1ab528c485c0';
const secret = process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788';
const HEADER = ['NameAr', 'NameEn', 'Price', 'Category', 'Description', 'Instructions'];

function queryResult(value) {
    const query = {
        select() { return query; },
        populate() { return query; },
        then(resolve, reject) { return Promise.resolve(value).then(resolve, reject); }
    };
    return query;
}

function createLab(tests = []) {
    return new Lab({
        _id: labId,
        name: 'مختبر العافية',
        email: 'lab@example.com',
        phone: '07700000123',
        address: 'Baghdad',
        city: 'بغداد',
        country: 'Iraq',
        ownerId,
        createdBy: adminId,
        tests
    });
}

function workbookBuffer(rows) {
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, XLSX.utils.aoa_to_sheet(rows), 'Tests');
    return XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
}

async function startServer(t, { role = 'admin', lab = createLab() } = {}) {
    t.mock.method(User, 'findById', () => queryResult({
        _id: new mongoose.Types.ObjectId(adminId),
        id: adminId,
        name: 'Test User',
        email: 'test-user@example.com',
        role,
        status: 'active'
    }));
    t.mock.method(Lab, 'findById', () => queryResult(lab));
    const save = t.mock.method(Lab.prototype, 'save', async function saveWithoutDatabase() {
        return this;
    });

    const app = express();
    app.use(express.json());
    app.use('/admin/api/labs', labRoutes);
    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    t.after(() => new Promise(resolve => server.close(resolve)));

    return {
        base: `http://127.0.0.1:${server.address().port}/admin/api/labs`,
        headers: { Authorization: `Bearer ${jwt.sign({ userId: adminId, role }, secret)}` },
        save,
        lab
    };
}

async function importFile(t, buffer, { filename = 'tests.xlsx', ...options } = {}) {
    const context = await startServer(t, options);
    const body = new FormData();
    body.append('file', new Blob([buffer]), filename);
    const response = await fetch(`${context.base}/${labId}/tests/import`, {
        method: 'POST',
        headers: context.headers,
        body
    });
    return { ...context, response, payload: await response.json() };
}

test('template downloads as an xlsx with an empty tests sheet first', async t => {
    const { base, headers } = await startServer(t);
    const response = await fetch(`${base}/tests/template`, { headers });

    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-type'), /spreadsheetml/);
    assert.match(response.headers.get('content-disposition'), /attachment; filename=".+\.xlsx"/);

    const workbook = XLSX.read(Buffer.from(await response.arrayBuffer()), { type: 'buffer' });
    const rows = XLSX.utils.sheet_to_json(workbook.Sheets[workbook.SheetNames[0]], { header: 1 });

    assert.deepEqual(rows, [HEADER], 'first sheet must hold only headers so nothing sample is imported');
    assert.ok(workbook.SheetNames.length >= 2, 'help sheet lists the allowed categories');
    assert.match(JSON.stringify(XLSX.utils.sheet_to_json(workbook.Sheets[workbook.SheetNames[1]], { header: 1 })), /Biochemistry/);
});

test('a filled-in template imports every valid row', async t => {
    const { response, payload, save, lab } = await importFile(t, workbookBuffer([
        HEADER,
        ['فيتامين د', 'Vitamin D', 15000.4, 'biochemistry', 'Serum level', 'No fasting'],
        ['تعداد الدم', 'CBC', '10,000', 'تحاليل الدم']
    ]));

    assert.equal(response.status, 200);
    assert.equal(payload.success, true);
    assert.equal(save.mock.callCount(), 1);
    assert.equal(lab.tests.length, 2);
    assert.equal(lab.tests[0].price, 15000);
    assert.equal(lab.tests[0].category, 'Biochemistry');
    assert.equal(lab.tests[0].instructions, 'No fasting');
    assert.equal(lab.tests[1].price, 10000);
    assert.equal(lab.tests[1].category, 'Blood Tests');
    assert.notEqual(lab.tests[0].code, lab.tests[1].code);
    assert.equal(lab.validateSync(), undefined);
    assert.equal(payload.results.added.length, 2);
    assert.ok(payload.results.added[0]._id, 'added tests are returned with their ids');
    assert.deepEqual(payload.results.errors, []);
    assert.deepEqual(payload.results.skipped, []);
});

test('Arabic-Indic digits in a price cell are understood', async t => {
    const { lab } = await importFile(t, workbookBuffer([
        HEADER,
        ['فيتامين د', 'Vitamin D', '١٥٠٠٠', 'General']
    ]));

    assert.equal(lab.tests[0].price, 15000);
});

test('bad rows are reported by their real Excel row and good rows still import', async t => {
    const { payload, lab } = await importFile(t, workbookBuffer([
        HEADER,
        ['جيد', 'Good', 1000, 'General'],
        [],
        ['', 'No Arabic', 1000, 'General'],
        ['بلا اسم', '', 1000, 'General'],
        ['سعر', 'Bad Price', 'abc', 'General'],
        ['فئة', 'Bad Category', 1000, 'Astrology']
    ]));

    assert.deepEqual(lab.tests.map(item => item.name), ['Good']);
    assert.deepEqual(payload.results.errors, [
        { row: 4, code: 'missingNameAr' },
        { row: 5, code: 'missingName' },
        { row: 6, code: 'invalidPrice' },
        { row: 7, code: 'invalidCategory' }
    ]);
});

test('names already in the lab or repeated in the file are skipped', async t => {
    const { payload, lab } = await importFile(t, workbookBuffer([
        HEADER,
        ['موجود', ' cbc ', 1000, 'General'],
        ['جديد', 'New Test', 1000, 'General'],
        ['مكرر', 'NEW TEST', 2000, 'General']
    ]), {
        lab: createLab([{ name: 'CBC', nameAr: 'تعداد', code: 'C1', price: 5, category: 'General' }])
    });

    assert.deepEqual(lab.tests.map(item => item.name), ['CBC', 'New Test']);
    assert.deepEqual(payload.results.skipped, [
        { row: 2, name: 'cbc' },
        { row: 4, name: 'NEW TEST' }
    ]);
});

test('nothing is saved when no row is valid', async t => {
    const { response, payload, save } = await importFile(t, workbookBuffer([
        HEADER,
        ['', '', '', '']  ,
        ['فئة', 'Bad Category', 1000, 'Astrology']
    ]));

    assert.equal(response.status, 200);
    assert.equal(save.mock.callCount(), 0);
    assert.equal(payload.results.added.length, 0);
});

test('a template with no rows is rejected as empty', async t => {
    const { response, payload, save } = await importFile(t, workbookBuffer([HEADER]));

    assert.equal(response.status, 400);
    assert.equal(payload.code, 'emptyFile');
    assert.equal(save.mock.callCount(), 0);
});

test('files that are not Excel workbooks are rejected', async t => {
    const { response, payload, save } = await importFile(t, Buffer.from('name,price'), { filename: 'tests.pdf' });

    assert.equal(response.status, 400);
    assert.equal(payload.code, 'invalidFile');
    assert.equal(save.mock.callCount(), 0);
});

test('oversized sheets are rejected before anything is added', async t => {
    const rows = [HEADER];
    for (let i = 0; i < 2001; i++) rows.push(['فحص', `Test ${i}`, 1000, 'General']);

    const { response, payload, save, lab } = await importFile(t, workbookBuffer(rows));

    assert.equal(response.status, 400);
    assert.equal(payload.code, 'tooManyRows');
    assert.equal(save.mock.callCount(), 0);
    assert.equal(lab.tests.length, 0);
});

test('import returns 404 for an unknown lab', async t => {
    const { response, save } = await importFile(t, workbookBuffer([
        HEADER,
        ['جيد', 'Good', 1000, 'General']
    ]), { lab: null });

    assert.equal(response.status, 404);
    assert.equal(save.mock.callCount(), 0);
});

test('non-admin users cannot import tests or download the template', async t => {
    const { response, save, base, headers, lab } = await importFile(t, workbookBuffer([
        HEADER,
        ['جيد', 'Good', 1000, 'General']
    ]), { role: 'lab' });

    assert.equal(response.status, 403);
    assert.equal(save.mock.callCount(), 0);
    assert.equal(lab.tests.length, 0);
    assert.equal((await fetch(`${base}/tests/template`, { headers })).status, 403);
});
