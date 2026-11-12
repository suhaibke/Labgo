const XLSX = require('xlsx');

const Lab = require('../models/Lab');
const arabicCategories = require('../i18n/languages/ar.json').tests.specializations;

const TEST_CATEGORIES = Lab.schema.path('tests').schema.path('category').enumValues;
const MAX_IMPORT_ROWS = 2000;
const TEMPLATE_COLUMNS = ['NameAr', 'NameEn', 'Price', 'Category', 'Description', 'Instructions'];

const clean = value => String(value ?? '').trim();

// Returns { test } ready to push onto Lab.tests, or { error } with a reason code.
function buildLabTest(input, codeSuffix = '') {
    const name = clean(input.name);
    const nameAr = clean(input.nameAr);
    const category = clean(input.category);
    const rawPrice = clean(input.price);
    const price = Math.round(Number(rawPrice));

    if (!name) return { error: 'missingName' };
    if (!nameAr) return { error: 'missingNameAr' };
    if (!rawPrice || !Number.isFinite(price) || price < 0) return { error: 'invalidPrice' };
    if (!TEST_CATEGORIES.includes(category)) return { error: 'invalidCategory' };

    return {
        test: {
            name,
            nameAr,
            code: `${category.toUpperCase().replace(/\s+/g, '_')}_${Date.now()}${codeSuffix}`,
            price,
            category,
            description: clean(input.description),
            instructions: clean(input.instructions)
        }
    };
}

function normalizePrice(value) {
    return clean(value)
        .replace(/[٠-٩]/g, digit => digit.charCodeAt(0) - 0x0660)
        .replace(/[,،٬\s]/g, '');
}

function resolveCategory(value) {
    const category = clean(value);
    return TEST_CATEGORIES.find(item =>
        item.toLowerCase() === category.toLowerCase() || arabicCategories[item] === category
    ) || category;
}

// Reads the first sheet into rows keyed by lower-cased header, each with its Excel row number.
function readTestRows(buffer) {
    const workbook = XLSX.read(buffer, { type: 'buffer' });
    const sheet = workbook.Sheets[workbook.SheetNames[0]];

    return XLSX.utils.sheet_to_json(sheet, { raw: true }).map(row => {
        const fields = {};
        for (const [key, value] of Object.entries(row)) {
            fields[key.toLowerCase().replace(/[\s_]+/g, '')] = value;
        }
        return { rowNumber: row.__rowNum__ + 1, fields };
    });
}

// Pushes valid, new rows onto lab.tests; invalid and duplicate rows are reported and left out.
function addImportedTests(lab, rows) {
    const results = { addedCount: 0, skipped: [], errors: [] };

    rows.forEach(({ rowNumber, fields }, index) => {
        const { test, error } = buildLabTest({
            name: fields.nameen,
            nameAr: fields.namear,
            price: normalizePrice(fields.price),
            category: resolveCategory(fields.category),
            description: fields.description,
            instructions: fields.instructions
        }, `_${index}`);

        if (error) {
            results.errors.push({ row: rowNumber, code: error });
            return;
        }

        const isDuplicate = lab.tests.some(existing =>
            existing.name.trim().toLowerCase() === test.name.toLowerCase()
        );
        if (isDuplicate) {
            results.skipped.push({ row: rowNumber, name: test.name });
            return;
        }

        lab.tests.push(test);
        results.addedCount += 1;
    });

    return results;
}

function buildTestsTemplate() {
    const workbook = XLSX.utils.book_new();

    // The first sheet stays header-only so sample data can never be imported by accident.
    const testsSheet = XLSX.utils.aoa_to_sheet([TEMPLATE_COLUMNS]);
    testsSheet['!cols'] = TEMPLATE_COLUMNS.map(() => ({ wch: 24 }));
    XLSX.utils.book_append_sheet(workbook, testsSheet, 'Tests');

    const helpSheet = XLSX.utils.aoa_to_sheet([
        ['العمود', 'مطلوب', 'الوصف'],
        ['NameAr', 'نعم', 'اسم الفحص بالعربية'],
        ['NameEn', 'نعم', 'اسم الفحص بالإنجليزية، والفحص الذي يتكرر اسمه يتم تخطيه'],
        ['Price', 'نعم', 'السعر بالدينار العراقي، أرقام فقط'],
        ['Category', 'نعم', 'إحدى الفئات المذكورة أدناه'],
        ['Description', 'لا', 'وصف الفحص'],
        ['Instructions', 'لا', 'تعليمات للمريض'],
        [],
        ['الفئات المسموحة (English)', 'الفئات المسموحة (العربية)'],
        ...TEST_CATEGORIES.map(category => [category, arabicCategories[category]])
    ]);
    helpSheet['!cols'] = [{ wch: 28 }, { wch: 28 }, { wch: 56 }];
    XLSX.utils.book_append_sheet(workbook, helpSheet, 'التعليمات');

    return XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
}

module.exports = {
    MAX_IMPORT_ROWS,
    addImportedTests,
    buildLabTest,
    buildTestsTemplate,
    readTestRows
};
