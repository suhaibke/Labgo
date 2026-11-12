const jwt = require('jsonwebtoken');
const User = require('../../models/User');
const Lab = require('../../models/Lab');

const auth = async (req, res, next) => {
    try {
        const token = req.header('Authorization')?.replace('Bearer ', '') ||
                     req.cookies?.token;

        if (!token) {
            // Check if this is a page request or API request
            if (req.path.startsWith('/api/') || req.xhr || req.headers.accept?.includes('application/json')) {
                return res.status(401).json({ success: false, message: 'Access denied. No token provided.' });
            } else {
                return res.status(401).render('auth/login', {
                    error: 'Authentication required. Please login.',
                    direction: 'ltr',
                    font: 'Inter, sans-serif'
                });
            }
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788');

        // Include password field only for user profile update endpoint
        const includePassword = req.path === '/api/user/profile' && req.method === 'PUT';
        const userQuery = User.findById(decoded.userId || decoded.id);
        if (!includePassword) {
            userQuery.select('-password');
        }
        const user = await userQuery;

        if (!user) {
            if (req.path.startsWith('/api/') || req.xhr || req.headers.accept?.includes('application/json')) {
                return res.status(401).json({ success: false, message: 'Invalid token.' });
            } else {
                return res.status(401).render('auth/login', {
                    error: 'Invalid or expired token. Please login again.',
                    direction: 'ltr',
                    font: 'Inter, sans-serif'
                });
            }
        }

        // Check if user has lab role
        if (user.role !== 'lab') {
            if (req.path.startsWith('/api/') || req.xhr || req.headers.accept?.includes('application/json')) {
                return res.status(403).json({ success: false, message: 'Access denied. Lab role required.' });
            } else {
                return res.status(403).render('auth/login', {
                    error: 'Access denied. Lab role required.',
                    direction: 'ltr',
                    font: 'Inter, sans-serif'
                });
            }
        }

        // Find the lab associated with this user
        const lab = await Lab.findOne({ ownerId: user._id });
        if (!lab) {
            if (req.path.startsWith('/api/') || req.xhr || req.headers.accept?.includes('application/json')) {
                return res.status(404).json({ success: false, message: 'Lab not found for this user.' });
            } else {
                return res.status(404).render('error', {
                    message: 'Lab not found for this user.',
                    error: null
                });
            }
        }

        req.user = user;
        req.lab = lab;
        next();
    } catch (error) {
        console.error('Lab auth middleware error:', error);
        if (req.path.startsWith('/api/') || req.xhr || req.headers.accept?.includes('application/json')) {
            res.status(401).json({ success: false, message: 'Invalid token.' });
        } else {
            res.status(401).render('auth/login', {
                error: 'Invalid or expired token. Please login again.',
                direction: 'ltr',
                font: 'Inter, sans-serif'
            });
        }
    }
};

module.exports = auth;