const express = require('express');
const router = express.Router();

// Import middleware
const { verifyToken } = require('../middleware/auth');
const { authorizeRole, authorizeResource, authorizeOwner } = require('../config/permissions');

// All routes in this file require authentication
router.use(verifyToken);

// Route accessible by all authenticated users
router.get('/profile', (req, res) => {
    res.json({
        success: true,
        message: 'Profile information',
        user: {
            id: req.user._id,
            name: req.user.name,
            email: req.user.email,
            role: req.user.role,
            birthDate: req.user.birthDate
        }
    });
});

// Route accessible only by admin
router.get('/admin-only', authorizeRole(['admin']), (req, res) => {
    res.json({
        success: true,
        message: 'Admin section - Only accessible by admins',
        timestamp: new Date().toISOString()
    });
});

// Route accessible by nurse and admin
router.get('/nurse-section', authorizeRole(['nurse', 'admin']), (req, res) => {
    res.json({
        success: true,
        message: 'Nurse section - Accessible by nurses and admins',
        userRole: req.userRole,
        data: {
            patients: [],
            appointments: []
        }
    });
});

// Route accessible by lab technician and admin
router.get('/lab-section', authorizeRole(['lab', 'admin']), (req, res) => {
    res.json({
        success: true,
        message: 'Lab section - Accessible by lab technicians and admins',
        userRole: req.userRole,
        data: {
            labTests: [],
            results: []
        }
    });
});

// Route accessible by all roles
router.get('/dashboard', authorizeRole(['patient', 'nurse', 'lab', 'admin']), (req, res) => {
    const roleInfo = {
        patient: { view: 'Your health data', edit: 'Your profile' },
        nurse: { view: 'Patient records', edit: 'Care plans' },
        lab: { view: 'Lab tests', edit: 'Test results' },
        admin: { view: 'All data', edit: 'System settings' }
    };

    res.json({
        success: true,
        message: 'Dashboard',
        userRole: req.userRole,
        permissions: roleInfo[req.userRole] || {}
    });
});

// Resource-based access control example
router.get('/lab-tests', authorizeResource('lab-tests'), (req, res) => {
    res.json({
        success: true,
        message: 'Lab tests - Access granted based on resource permission',
        userRole: req.userRole,
        data: [
            { id: 1, name: 'Blood Test', status: 'Pending' },
            { id: 2, name: 'X-Ray', status: 'Completed' }
        ]
    });
});

// Owner-based access control example
// Patients can only access their own records
router.get('/records/:id', authorizeOwner('id'), (req, res) => {
    res.json({
        success: true,
        message: 'Medical records',
        userRole: req.userRole,
        userId: req.userId,
        requestedId: req.params.id,
        record: {
            id: req.params.id,
            patientId: req.params.id,
            data: 'Sensitive medical information'
        }
    });
});

// Example: Multiple role authorization
router.post('/create-appointment', authorizeRole(['nurse', 'lab', 'admin']), (req, res) => {
    res.json({
        success: true,
        message: 'Appointment created successfully',
        createdBy: req.userRole,
        appointment: {
            id: Date.now(),
            ...req.body
        }
    });
});

// Example: Checking user's own resource
router.get('/my-data', (req, res) => {
    res.json({
        success: true,
        message: 'Your personal data',
        userId: req.userId,
        role: req.userRole,
        data: {
            // User-specific data would go here
            lastLogin: new Date().toISOString()
        }
    });
});

module.exports = router;
