const express = require('express');

const router = express.Router();

router.get('/login', (req, res) => {
    res.render('auth/login');
});

router.get(['/register', '/otp'], (req, res) => {
    res.redirect('/auth/login');
});

module.exports = router;
