// Web pages for the labs' marketplace and support tickets (APIs in market-support.js).
const express = require('express');

const router = express.Router();

function langOf(req) {
    const currentLang = req.cookies?.lang || req.headers['accept-language']?.split(',')[0]?.split('-')[0] || 'ar';
    return { currentLang, direction: ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr' };
}

for (const [path, view, section] of [['/market', 'lab-market', 'market'], ['/support', 'lab-support', 'support']]) {
    router.get(path, (req, res) => {
        res.render('dashboard/' + view, { lab: req.lab, user: req.user, title: req.lab.name, ...langOf(req), activeSection: section });
    });
}

module.exports = router;
