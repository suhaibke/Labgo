const assert = require('node:assert/strict');
const path = require('node:path');
const test = require('node:test');
const ejs = require('ejs');

const storeLinks = require('../config/storeLinks');

const viewsDirectory = path.join(__dirname, '..', 'views');
const translate = key => key;
const viewLocals = {
    __: translate,
    currentLang: 'en',
    direction: 'ltr',
    font: 'Inter, sans-serif',
    storeLinks
};

test('store links match the published LabGo listings', () => {
    assert.deepEqual(storeLinks, {
        android: 'https://play.google.com/store/apps/details?id=com.labgo.app&hl=en',
        ios: 'https://apps.apple.com/us/app/labgo-iraq/id6792129656'
    });
});

test('landing download buttons render both published store destinations', async () => {
    const html = await ejs.renderFile(path.join(viewsDirectory, 'landing.ejs'), viewLocals);

    const decodedHtml = html.replaceAll('&amp;', '&');
    assert.match(decodedHtml, new RegExp(`href="${storeLinks.android.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}"`));
    assert.match(decodedHtml, new RegExp(`href="${storeLinks.ios.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}"`));
});

test('package share page sends visitors to the stores, never to an APK', async () => {
    const pkg = { _id: 'abc123', name: 'Hair', nameAr: 'تساقط الشعر', price: 40000, testIds: ['a', 'b'] };
    const lab = { name: 'Secret Lab', city: 'Mosul' };
    const html = await ejs.renderFile(path.join(viewsDirectory, 'package-share.ejs'), {
        found: true, pkg, lab, storeLinks
    });

    assert.doesNotMatch(html, /labgo\.apk/);
    assert.ok(html.includes(`var stores = ${JSON.stringify(storeLinks)};`));
    assert.match(html, /intent:\/\/package\/abc123#Intent;scheme=labgo;package=com\.labgo\.app/);
    assert.doesNotMatch(html.match(/<meta property="og:description"[^>]*>/)[0], /Secret Lab/);
});

test('management login patient message renders both published store destinations and no signup link', async () => {
    const html = await ejs.renderFile(path.join(viewsDirectory, 'auth', 'login.ejs'), {
        ...viewLocals,
        error: null
    });

    const decodedHtml = html.replaceAll('&amp;', '&');
    assert.match(decodedHtml, new RegExp(`href="${storeLinks.android.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}"`));
    assert.match(decodedHtml, new RegExp(`href="${storeLinks.ios.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}"`));
    assert.doesNotMatch(html, /href="\/auth\/register"/);
});
