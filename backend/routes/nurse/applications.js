const express = require('express');
const router = express.Router();
const path = require('path');

// Import models
const NurseApplication = require('../../models/NurseApplication');
const User = require('../../models/User');

// Import middleware
const { verifyToken } = require('../../middleware/auth');
const { r2FieldsUpload } = require('../../middleware/r2Upload');
const r2Service = require('../../services/r2Service');

// R2 upload middleware for nurse application documents
const uploadNurseDocuments = r2FieldsUpload('nurseApplications', [
    { name: 'nationalCardImageFront', maxCount: 1 },
    { name: 'nationalCardImageBack', maxCount: 1 },
    { name: 'certificateImage', maxCount: 1 }
], 'nurse-app-');

/**
 * @route   POST /api/nurse/apply
 * @desc    Submit a nurse application
 * @access  Private (Patient role)
 */
router.post('/apply', verifyToken, ...uploadNurseDocuments, async (req, res) => {
    try {
        const userId = req.userId;
        const user = await User.findById(userId);

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Check if user is a patient
        if (user.role !== 'patient') {
            return res.status(400).json({
                success: false,
                message: 'Only patients can apply for nurse position'
            });
        }

        // Validate that user has required profile information
        if (!user.phone || !user.gender || !user.birthDate) {
            return res.status(400).json({
                success: false,
                message: 'Please complete your profile first (phone, gender, and date of birth are required)',
                missingFields: {
                    phone: !user.phone,
                    gender: !user.gender,
                    birthDate: !user.birthDate,
                }
            });
        }

        // Check for existing pending application
        const existingApplication = await NurseApplication.hasPendingApplication(userId);
        if (existingApplication) {
            return res.status(400).json({
                success: false,
                message: 'You already have a pending application'
            });
        }

        const {
            city,
            zone,
            address,
            latitude,
            longitude,
            ownsCar,
            isEmployed,
            additionalInfo
        } = req.body;

        // Validate required fields
        if (!city || !zone) {
            return res.status(400).json({
                success: false,
                message: 'City and zone are required'
            });
        }

        const files = req.files || {};
        const frontFile = files.nationalCardImageFront?.[0];
        const backFile = files.nationalCardImageBack?.[0];
        const certificateFile = files.certificateImage?.[0];

        if (!frontFile?.r2Url || !backFile?.r2Url || !certificateFile?.r2Url) {
            return res.status(400).json({
                success: false,
                message: 'National card (front and back) and certificate images are required'
            });
        }

        const gender = String(user.gender || '').toLowerCase();
        const lat = latitude !== undefined && latitude !== '' ? Number(latitude) : NaN;
        const lng = longitude !== undefined && longitude !== '' ? Number(longitude) : NaN;

        const application = new NurseApplication({
            userId: userId,
            personalInfo: {
                name: user.name,
                email: user.email || null,
                phone: user.phone,
                dateOfBirth: user.birthDate,
                gender: gender === 'female' ? 'female' : 'male',
            },
            nationalCardImageFront: frontFile.r2Url,
            nationalCardImageBack: backFile.r2Url,
            certificateImage: certificateFile.r2Url,
            location: {
                city,
                zone,
                address: address || '',
                coordinates: {
                    latitude: Number.isFinite(lat) ? lat : undefined,
                    longitude: Number.isFinite(lng) ? lng : undefined,
                }
            },
            questionnaire: {
                ownsCar: ownsCar === 'true' || ownsCar === true,
                isEmployed: isEmployed === 'true' || isEmployed === true,
            },
            additionalInfo: additionalInfo || '',
        });

        await application.save();

        res.status(201).json({
            success: true,
            message: 'Application submitted successfully',
            data: {
                applicationId: application._id,
                status: application.status,
                submittedAt: application.submittedAt,
            }
        });

    } catch (error) {
        console.error('Nurse application error:', error);
        if (error.name === 'ValidationError') {
            const details = Object.values(error.errors || {}).map((e) => e.message).join(', ');
            return res.status(400).json({
                success: false,
                message: details || 'Invalid application data',
            });
        }
        res.status(500).json({
            success: false,
            message: error.message || 'Server error while submitting application',
        });
    }
});

/**
 * @route   GET /api/nurse/my-application
 * @desc    Get current user's nurse application
 * @access  Private
 */
router.get('/my-application', verifyToken, async (req, res) => {
    try {
        const userId = req.userId;
        const application = await NurseApplication.getByUserId(userId);

        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'No application found'
            });
        }

        res.json({
            success: true,
            data: {
                application,
            }
        });

    } catch (error) {
        console.error('Get application error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error while fetching application'
        });
    }
});

/**
 * @route   GET /api/nurse/applications
 * @desc    Get all nurse applications (Admin only)
 * @access  Private (Admin)
 */
router.get('/applications', verifyToken, async (req, res) => {
    try {
        const userId = req.userId;
        const user = await User.findById(userId);

        if (!user || user.role !== 'admin') {
            return res.status(403).json({
                success: false,
                message: 'Access denied. Admin only.'
            });
        }

        const { status, page = 1, limit = 20 } = req.query;
        const query = {};
        if (status) query.status = status;

        const applications = await NurseApplication.find(query)
            .populate('userId', 'name email phone')
            .populate('reviewDetails.reviewedBy', 'name email')
            .sort({ submittedAt: -1 })
            .limit(limit * 1)
            .skip((page - 1) * limit);

        const total = await NurseApplication.countDocuments(query);

        res.json({
            success: true,
            data: {
                applications,
                total,
                page: parseInt(page),
                pages: Math.ceil(total / limit),
            }
        });

    } catch (error) {
        console.error('Get applications error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error while fetching applications'
        });
    }
});

/**
 * @route   GET /api/nurse/applications/:id
 * @desc    Get single nurse application by ID (Admin only)
 * @access  Private (Admin)
 */
router.get('/applications/:id', verifyToken, async (req, res) => {
    try {
        const userId = req.userId;
        const user = await User.findById(userId);

        if (!user || user.role !== 'admin') {
            return res.status(403).json({
                success: false,
                message: 'Access denied. Admin only.'
            });
        }

        const application = await NurseApplication.findById(req.params.id)
            .populate('userId', 'name email phone birthDate gender')
            .populate('reviewDetails.reviewedBy', 'name email')
            .populate('nurseUserId', 'name email role');

        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        res.json({
            success: true,
            data: { application }
        });

    } catch (error) {
        console.error('Get application error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error while fetching application'
        });
    }
});

/**
 * @route   POST /api/nurse/applications/:id/approve
 * @desc    Approve a nurse application (Admin only)
 * @access  Private (Admin)
 */
router.post('/applications/:id/approve', verifyToken, async (req, res) => {
    try {
        const userId = req.userId;
        const user = await User.findById(userId);

        if (!user || user.role !== 'admin') {
            return res.status(403).json({
                success: false,
                message: 'Access denied. Admin only.'
            });
        }

        const application = await NurseApplication.findById(req.params.id);
        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        if (application.status !== 'pending' && application.status !== 'under_review') {
            return res.status(400).json({
                success: false,
                message: 'Application cannot be approved'
            });
        }

        const { notes } = req.body;

        // Update the original user to nurse role
        const applicantUser = await User.findById(application.userId);
        applicantUser.role = 'nurse';
        await applicantUser.save();

        // Approve the application
        await application.approve(userId, applicantUser._id, notes);

        res.json({
            success: true,
            message: 'Application approved successfully',
            data: { application }
        });

    } catch (error) {
        console.error('Approve application error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error while approving application'
        });
    }
});

/**
 * @route   POST /api/nurse/applications/:id/reject
 * @desc    Reject a nurse application (Admin only)
 * @access  Private (Admin)
 */
router.post('/applications/:id/reject', verifyToken, async (req, res) => {
    try {
        const userId = req.userId;
        const user = await User.findById(userId);

        if (!user || user.role !== 'admin') {
            return res.status(403).json({
                success: false,
                message: 'Access denied. Admin only.'
            });
        }

        const application = await NurseApplication.findById(req.params.id);
        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        if (application.status !== 'pending' && application.status !== 'under_review') {
            return res.status(400).json({
                success: false,
                message: 'Application cannot be rejected'
            });
        }

        const { reason } = req.body;

        if (!reason) {
            return res.status(400).json({
                success: false,
                message: 'Rejection reason is required'
            });
        }

        await application.reject(userId, reason);

        res.json({
            success: true,
            message: 'Application rejected',
            data: { application }
        });

    } catch (error) {
        console.error('Reject application error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error while rejecting application'
        });
    }
});

/**
 * @route   POST /api/nurse/applications/:id/review
 * @desc    Mark application as under review (Admin only)
 * @access  Private (Admin)
 */
router.post('/applications/:id/review', verifyToken, async (req, res) => {
    try {
        const userId = req.userId;
        const user = await User.findById(userId);

        if (!user || user.role !== 'admin') {
            return res.status(403).json({
                success: false,
                message: 'Access denied. Admin only.'
            });
        }

        const application = await NurseApplication.findById(req.params.id);
        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        if (application.status !== 'pending') {
            return res.status(400).json({
                success: false,
                message: 'Application is not in pending status'
            });
        }

        await application.markAsUnderReview(userId);

        res.json({
            success: true,
            message: 'Application marked as under review',
            data: { application }
        });

    } catch (error) {
        console.error('Mark review error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error while updating application'
        });
    }
});

module.exports = router;
