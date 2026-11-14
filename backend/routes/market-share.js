// Public share page for a store listing (product, auction or lab for sale).
// Anyone with the link sees a read-only card; labs open it inside the store.
// The same link pasted into a store banner makes the banner open the listing.
const express = require('express');
const mongoose = require('mongoose');
const MarketListing = require('../models/MarketListing');
const { baseUrl } = require('../helpers/base-url');

const router = express.Router();
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
const money = (n) => Math.round(Number(n) || 0).toLocaleString('en-US');
const KIND = { product: 'منتج', auction: 'مزاد', lab_sale: 'مختبر للبيع', lab_auction: 'مزاد مختبر' };

function page({ status = 200, title, body, og = '' }) {
    return { status, html: `<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(title)}</title>${og}
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@400;600;700&family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
<style>*{box-sizing:border-box}body{margin:0;min-height:100vh;display:grid;place-items:center;background:#F6F6F3;font-family:"Inter","IBM Plex Sans Arabic",sans-serif;color:#17191E;padding:16px}
.c{width:min(460px,100%);background:#fff;border:1px solid #E6E5E0;border-radius:14px;overflow:hidden;box-shadow:0 4px 12px rgba(23,25,30,.06)}
.img{aspect-ratio:4/3;background:#F3F3EF;display:grid;place-items:center;color:#A3A6AD;font-size:13px}.img img{width:100%;height:100%;object-fit:cover}
.b{padding:18px 20px 20px}.k{display:inline-block;height:22px;line-height:22px;padding:0 8px;border-radius:6px;background:#FFF2EA;color:#FF5A00;font-size:11.5px;font-weight:600}
h1{font-size:19px;line-height:1.4;margin:10px 0 4px}.m{color:#848891;font-size:13px;margin:0}.p{font-size:24px;font-weight:700;margin:14px 0 2px;font-variant-numeric:tabular-nums}.p small{font-size:13px;color:#848891;font-weight:500}
.d{margin:12px 0 0;color:#3A3D45;font-size:13.5px;line-height:1.7;white-space:pre-line}
a.btn{display:flex;align-items:center;justify-content:center;height:42px;margin-top:18px;border-radius:8px;background:#FF5A00;color:#fff;font-weight:600;font-size:14px;text-decoration:none}
.f{text-align:center;color:#848891;font-size:12px;margin-top:12px}</style></head><body><main>${body}</main></body></html>` };
}

router.get('/m/:id', async (req, res) => {
    res.set('X-Robots-Tag', 'noindex');
    let out = page({ status: 404, title: 'LabGo', body: '<div class="c"><div class="b"><h1>الإعلان غير متوفر</h1><p class="m">This listing is no longer available.</p></div></div>' });
    try {
        if (mongoose.Types.ObjectId.isValid(req.params.id)) {
            const l = await MarketListing.findById(req.params.id).populate('labId', 'name city').lean();
            if (l && l.approvalStatus === 'approved' && l.status !== 'removed') {
                const auction = l.kind === 'auction' || l.kind === 'lab_auction';
                const price = auction ? (l.currentBid || l.price) : l.price;
                const img = (l.images || [])[0] || '';
                const url = `${baseUrl(req)}/m/${l._id}`;
                const desc = `${KIND[l.kind] || ''} · ${money(price)} IQD${l.labId?.name ? ` · ${l.labId.name}` : ''}`;
                out = page({
                    title: `${l.title} · LabGo`,
                    og: `<meta property="og:title" content="${esc(l.title)}"><meta property="og:description" content="${esc(desc)}"><meta property="og:url" content="${esc(url)}">${img ? `<meta property="og:image" content="${esc(img)}">` : ''}<meta property="og:type" content="product">`,
                    body: `<div class="c"><div class="img">${img ? `<img src="${esc(img)}" alt="">` : 'LabGo'}</div><div class="b">
<span class="k">${esc(KIND[l.kind] || '')}</span><h1>${esc(l.title)}</h1>
<p class="m">${esc([l.labId?.name, l.labId?.city].filter(Boolean).join(' · '))}</p>
<div class="p"><span dir="ltr">${money(price)}</span> <small>IQD${auction ? ' · أعلى مزايدة' : ''}</small></div>
${l.description ? `<p class="d">${esc(String(l.description).slice(0, 400))}</p>` : ''}
<a class="btn" href="/lab/market?item=${l._id}">فتح في متجر LabGo</a></div></div><p class="f">متجر LabGo للمختبرات</p>`,
                });
            }
        }
    } catch (error) {
        console.error('Market share page error:', error);
    }
    res.status(out.status).send(out.html);
});

module.exports = router;
