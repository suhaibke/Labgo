const jwt = require('jsonwebtoken');
const User = require('../../models/User');

const auth = async (req, res, next) => {
    try {
        // Try to get token from Authorization header first, then from cookies
        let token = req.header('Authorization')?.replace('Bearer ', '');
        
        if (!token && req.cookies?.token) {
            token = req.cookies.token;
        }

        if (!token) {
            return res.status(401).json({ success: false, message: 'Access denied. No token provided.' });
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788');
        const user = await User.findById(decoded.userId).select('-password');

        if (!user) {
            return res.status(401).json({ success: false, message: 'Invalid token.' });
        }

        // Check if user is admin
        if (user.role !== 'admin') {
            return res.status(403).json({ success: false, message: 'Access denied. Admin role required.' });
        }

        req.user = user;
        next();
    } catch (error) {
        console.error('Auth middleware error:', error);
        res.status(401).json({ success: false, message: 'Invalid token.' });
    }
};

module.exports = auth;