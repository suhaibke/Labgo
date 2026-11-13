// Auctions end on their own: the first time an ended auction is looked at,
// the highest bidder wins and both labs are notified.
const MarketListing = require('../models/MarketListing');
const labNotify = require('./labNotify');
const notifyLab = (...a) => labNotify.notifyLab(...a);

const isAuction = (l) => l.kind === 'auction' || l.kind === 'lab_auction';

async function settle(listing) {
    if (!isAuction(listing) || listing.settledAt || !listing.endsAt || listing.endsAt > new Date()) return listing;
    const top = (listing.bids || []).reduce((best, b) => (!best || b.amount > best.amount ? b : best), null);
    const res = await MarketListing.updateOne({ _id: listing._id, settledAt: null }, {
        $set: { settledAt: new Date(), status: top ? 'sold' : 'ended', winnerLabId: top ? top.labId : null },
    });
    if (!res.modifiedCount) return listing; // settled by another request
    listing.settledAt = new Date();
    listing.status = top ? 'sold' : 'ended';
    listing.winnerLabId = top ? top.labId : null;
    if (top) {
        const amount = Number(top.amount).toLocaleString('en-US');
        await notifyLab(top.labId, {
            title: `فزت بالمزاد: ${listing.title}`,
            body: `مزايدتك ${amount} د.ع هي الأعلى. سيتواصل معك فريق LabGo لإتمام البيع.`,
            data: { type: 'auction_won', listingId: String(listing._id) },
        });
        await notifyLab(listing.labId, {
            title: `انتهى مزادك: ${listing.title}`,
            body: `أعلى مزايدة ${amount} د.ع من ${top.labName || 'مختبر'}.`,
            data: { type: 'auction_ended', listingId: String(listing._id) },
        });
    } else {
        await notifyLab(listing.labId, { title: `انتهى مزادك: ${listing.title}`, body: 'لم تصل أي مزايدة.', data: { type: 'auction_ended', listingId: String(listing._id) } });
    }
    return listing;
}

async function settleDue() {
    const due = await MarketListing.find({ kind: { $in: ['auction', 'lab_auction'] }, approvalStatus: 'approved', settledAt: null, endsAt: { $lte: new Date() } }).limit(50);
    for (const l of due) await settle(l);
}

module.exports = { settle, settleDue, isAuction };
