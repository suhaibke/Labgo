const User = require('../models/User');

/**
 * Role-based authorization middleware
 * @param {Array} allowedRoles - Array of allowed roles
 * @returns {Function} Express middleware function
 */
const authorizeRole = (allowedRoles) => {
    return async (req, res, next) => {
        try {
            // Check if user has a role
            if (!req.user || !req.user.role) {
                return res.status(403).json({
                    success: false,
                    message: 'Access denied: User role not found'
                });
            }

            // Check if user's role is in the allowed roles
            if (!allowedRoles.includes(req.user.role)) {
                return res.status(403).json({
                    success: false,
                    message: 'Access denied: Insufficient permissions',
                    required: allowedRoles,
                    current: req.user.role
                });
            }

            // Add role info to request for later use
            req.userRole = req.user.role;
            next();
        } catch (error) {
            console.error('Authorization error:', error);
            return res.status(500).json({
                success: false,
                message: 'Server error during authorization'
            });
        }
    };
};

/**
 * Resource-based authorization middleware
 * @param {string} resourceType - Type of resource being accessed
 * @returns {Function} Express middleware function
 */
const authorizeResource = (resourceType) => {
    return async (req, res, next) => {
        try {
            const userRole = req.user.role;

            // Define resource permissions based on roles
            const resourcePermissions = {
                'lab-tests': ['lab', 'nurse', 'admin'],
                'patient-records': ['nurse', 'admin', 'patient'],
                'appointments': ['nurse', 'lab', 'admin', 'patient'],
                'results': ['lab', 'nurse', 'admin', 'patient'],
                'billing': ['admin'],
                'system-settings': ['admin']
            };

            // Check if role has permission for this resource type
            const allowedRoles = resourcePermissions[resourceType];
            if (!allowedRoles || !allowedRoles.includes(userRole)) {
                return res.status(403).json({
                    success: false,
                    message: `Access denied: Cannot access ${resourceType} resource`,
                    required: allowedRoles || 'No permissions defined',
                    current: userRole
                });
            }

            req.resourceType = resourceType;
            next();
        } catch (error) {
            console.error('Resource authorization error:', error);
            return res.status(500).json({
                success: false,
                message: 'Server error during resource authorization'
            });
        }
    };
};

/**
 * Owner-based authorization middleware
 * Ensures users can only access their own resources unless they're admin
 * @param {string} userIdParam - Parameter name containing the user ID to check against
 * @returns {Function} Express middleware function
 */
const authorizeOwner = (userIdParam) => {
    return async (req, res, next) => {
        try {
            const currentUserId = req.user._id.toString();
            const targetUserId = req.params[userIdParam];

            // Admins can access any resource
            if (req.user.role === 'admin') {
                req.isOwner = true;
                return next();
            }

            // Check if user is trying to access their own resource
            if (currentUserId !== targetUserId) {
                return res.status(403).json({
                    success: false,
                    message: 'Access denied: You can only access your own resources',
                    currentUserId,
                    targetUserId
                });
            }

            req.isOwner = true;
            next();
        } catch (error) {
            console.error('Owner authorization error:', error);
            return res.status(500).json({
                success: false,
                message: 'Server error during owner authorization'
            });
        }
    };
};

/**
 * Custom permission checker for complex authorization rules
 * @param {Function} permissionCheck - Custom permission checking function
 * @returns {Function} Express middleware function
 */
const authorize = (permissionCheck) => {
    return async (req, res, next) => {
        try {
            const hasPermission = await permissionCheck(req.user, req);

            if (!hasPermission) {
                return res.status(403).json({
                    success: false,
                    message: 'Access denied: Custom authorization failed'
                });
            }

            next();
        } catch (error) {
            console.error('Custom authorization error:', error);
            return res.status(500).json({
                success: false,
                message: 'Server error during custom authorization'
            });
        }
    };
};

/**
 * Check if user has specific permission
 * @param {Object} user - User object
 * @param {string} permission - Permission string to check
 * @returns {boolean} - Whether user has the permission
 */
const hasPermission = (user, permission) => {
    const rolePermissions = {
        'admin': [
            'read:all', 'write:all', 'delete:all',
            'manage:users', 'manage:system', 'view:analytics'
        ],
        'lab': [
            'read:lab-tests', 'write:lab-tests', 'read:results', 'write:results',
            'read:appointments', 'write:appointments'
        ],
        'nurse': [
            'read:patients', 'write:patients', 'read:appointments', 'write:appointments',
            'read:lab-tests', 'read:results'
        ],
        'patient': [
            'read:own-data', 'write:own-data', 'read:own-appointments', 'write:own-appointments',
            'read:own-results', 'read:own-lab-tests'
        ]
    };

    return rolePermissions[user.role]?.includes(permission) || false;
};

module.exports = {
    authorizeRole,
    authorizeResource,
    authorizeOwner,
    authorize,
    hasPermission
};