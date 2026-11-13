const { jwtSecret } = require('../../config/secrets');
const jwt = require('jsonwebtoken');
const User = require('../../models/User');
const Lab = require('../../models/Lab');
const { PERMISSIONS, canAccess, labRoles, homeFor } = require('../../helpers/lab-permissions');

function isApiRequest(req) {
    return req.path.startsWith('/api/') || req.xhr || req.headers.accept?.includes('application/json');
}

function deny(req, res, status, message) {
    if (isApiRequest(req)) return res.status(status).json({ success: false, message });
    return res.status(status).render('auth/login', { error: message, direction: 'ltr', font: 'Inter, sans-serif' });
}

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

        const decoded = jwt.verify(token, jwtSecret());

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

        // Find the lab: owned by this user, or the lab this staff member works at.
        let lab = await Lab.findOne({ ownerId: user._id });
        const isOwner = Boolean(lab);
        let permissions = PERMISSIONS;
        if (!lab && user.labStaff?.labId) {
            if (user.labStaff.active === false) {
                return deny(req, res, 403, 'This account has been disabled by the lab.');
            }
            lab = await Lab.findById(user.labStaff.labId);
            const role = lab ? labRoles(lab).find((r) => r.key === user.labStaff.roleKey) : null;
            permissions = role ? role.permissions : [];
        }
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
        req.isLabOwner = isOwner;
        req.labPermissions = permissions;
        res.locals.labPermissions = permissions;
        res.locals.isLabOwner = isOwner;
        res.locals.labCan = (path) => canAccess(String(path).replace(/^\/lab/, ''), permissions, isOwner);

        if (!canAccess(req.path, permissions, isOwner)) {
            if (isApiRequest(req)) {
                return res.status(403).json({ success: false, message: 'You do not have permission for this action.' });
            }
            return res.redirect(homeFor(permissions, isOwner));
        }
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