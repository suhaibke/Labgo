const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Verify JWT token middleware
const verifyToken = async (req, res, next) => {
    try {
        // Get token from header
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'No token provided. Access denied.'
            });
        }

        const token = authHeader.substring(7);

        // Verify token
        const decoded = jwt.verify(
            token,
            process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788'
        );

        // Get user from database
        const user = await User.findById(decoded.userId).select('-password');

        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'User not found. Token is invalid.'
            });
        }

        // Check if user is blocked
        if (user.status === 'blocked') {
            return res.status(403).json({
                success: false,
                message: 'Your account has been blocked. Please contact support.',
                userBlocked: true,
                blockReason: user.blockReason || 'No reason provided',
                blockedAt: user.blockedAt
            });
        }

        // Add user to request object
        req.user = user;
        req.userId = user._id;
        req.userRole = user.role;

        next();

    } catch (error) {
        console.error('Token verification error:', error);

        if (error.name === 'JsonWebTokenError') {
            return res.status(401).json({
                success: false,
                message: 'Invalid token'
            });
        }

        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({
                success: false,
                message: 'Token expired. Please login again.'
            });
        }

        res.status(500).json({
            success: false,
            message: 'Server error during token verification',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
};

// Verify JWT token middleware for password operations (includes password field)
const verifyTokenWithPassword = async (req, res, next) => {
    try {
        // Get token from header
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'No token provided. Access denied.'
            });
        }

        const token = authHeader.substring(7);

        // Verify token
        const decoded = jwt.verify(
            token,
            process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788'
        );

        // Get user from database with password field
        const user = await User.findById(decoded.userId);

        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'User not found. Token is invalid.'
            });
        }

        // Check if user is blocked
        if (user.status === 'blocked') {
            return res.status(403).json({
                success: false,
                message: 'Your account has been blocked. Please contact support.',
                userBlocked: true,
                blockReason: user.blockReason || 'No reason provided',
                blockedAt: user.blockedAt
            });
        }

        // Add user to request object
        req.user = user;
        req.userId = user._id;
        req.userRole = user.role;

        next();

    } catch (error) {
        console.error('Token verification error:', error);

        if (error.name === 'JsonWebTokenError') {
            return res.status(401).json({
                success: false,
                message: 'Invalid token'
            });
        }

        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({
                success: false,
                message: 'Token expired. Please login again.'
            });
        }

        res.status(500).json({
            success: false,
            message: 'Server error during token verification',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
};

// Optional auth middleware - populates req.user if token present, but allows anonymous access
const optionalAuth = async (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            // No token - allow anonymous access
            req.user = null;
            req.userId = null;
            req.userRole = null;
            return next();
        }

        const token = authHeader.substring(7);

        const decoded = jwt.verify(
            token,
            process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788'
        );

        const user = await User.findById(decoded.userId).select('-password');

        if (user && user.status !== 'blocked') {
            req.user = user;
            req.userId = user._id;
            req.userRole = user.role;
        } else {
            req.user = null;
            req.userId = null;
            req.userRole = null;
        }

        next();
    } catch (error) {
        // Token invalid/expired - still allow anonymous access
        req.user = null;
        req.userId = null;
        req.userRole = null;
        next();
    }
};

module.exports = { verifyToken, verifyTokenWithPassword, optionalAuth };
