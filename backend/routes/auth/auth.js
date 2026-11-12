const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const User = require('../../models/User');
const Lab = require('../../models/Lab');
const otpService = require('../../services/otpService');
const { buildPublicPatient } = require('../../helpers/public-registration');
const auth = require('../../middleware/auth');
const r2Service = require('../../services/r2Service');
const { r2SingleUpload } = require('../../middleware/r2Upload');

const router = express.Router();

const uploadProfilePicture = r2SingleUpload('profilePictures', 'profilePicture', 'profile-');

// Valid Iraqi cities for registration
const VALID_CITIES = ['بغداد', 'البصرة', 'نينوى', 'الأنبار', 'كركوك', 'صلاح الدين', 'ديالى', 'بابل', 'كربلاء', 'النجف', 'القادسية', 'المثنى', 'واسط', 'ذي قار', 'ميسان', 'أربيل', 'السليمانية', 'دهوك'];

function getPhoneLoginCandidates(value) {
    const raw = value.trim();
    let digits = raw.replace(/\D/g, '');

    if (digits.startsWith('00964')) {
        digits = digits.slice(2);
    }

    const local = digits.startsWith('964') ? `0${digits.slice(3)}` : digits;
    const international = local.startsWith('0') ? `964${local.slice(1)}` : local;

    return [...new Set([raw, digits, local, international, `+${international}`].filter(Boolean))];
}

async function findByPhone(Model, candidates, extraQuery = {}) {
    for (const phone of candidates) {
        const record = await Model.findOne({ phone, ...extraQuery });
        if (record) return record;
    }
    return null;
}

// Register endpoint
router.post('/register', [
    body('name').trim().notEmpty().withMessage('Name is required'),
    body('email').optional({ checkFalsy: true }).isEmail().withMessage('Invalid email format').normalizeEmail(),
    body('phone').trim().notEmpty().withMessage('Phone number is required').custom(value => {
        const phoneRegex = /^[\d\s\-\+\(\)]+$/;
        if (!phoneRegex.test(value) || value.replace(/\D/g, '').length < 10) {
            throw new Error('Invalid phone number format');
        }
        return true;
    }),
    body('city').trim().notEmpty().withMessage('City is required').isIn(VALID_CITIES).withMessage('Invalid city'),
    body('gender').isIn(['male', 'female']).withMessage('Gender must be male or female'),
    body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters long'),
    body('birthDate').notEmpty().withMessage('Birth date is required')
], async (req, res) => {
    try {
        // Check for validation errors
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: errors.array()
            });
        }

        const { name, email, phone, city, gender, password, birthDate } = req.body;

        // Check if user already exists (only relevant when an email was provided)
        if (email) {
            const existingUser = await User.findOne({ email });
            if (existingUser) {
                return res.status(409).json({
                    success: false,
                    message: 'User with this email already exists'
                });
            }
        }

        // Check if phone number already exists, under any equivalent format
        // (raw/local/international) - a plain exact match would let someone
        // register a duplicate of an existing account just by typing their
        // number slightly differently.
        const existingPhone = await findByPhone(User, getPhoneLoginCandidates(phone));
        if (existingPhone) {
            return res.status(409).json({
                success: false,
                message: 'User with this phone number already exists'
            });
        }

        // Hash password
        const salt = await bcrypt.genSalt(12);
        const hashedPassword = await bcrypt.hash(password, salt);

        // Create new user
        const user = new User(buildPublicPatient({
            name,
            email,
            phone,
            city,
            gender,
            birthDate
        }, hashedPassword));

        await user.save();

        // Generate JWT token
        const token = jwt.sign(
            { userId: user._id, email: user.email, role: user.role },
            process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788',
            { expiresIn: process.env.JWT_EXPIRES_IN || '10y' }
        );

        // Return success response (don't include password)
        res.status(201).json({
            success: true,
            message: 'User registered successfully',
            token,
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                phone: user.phone,
                city: user.city,
                gender: user.gender,
                role: user.role,
                birthDate: user.birthDate
            }
        });

    } catch (error) {
        console.error('Registration error:', error);
        console.error('Error stack:', error.stack);
        console.error('Request body:', req.body);
        res.status(500).json({
            success: false,
            message: 'Server error during registration',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined,
            stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
        });
    }
});

// Login endpoint
router.post('/login', [
    body('loginInput')
        .trim()
        .notEmpty()
        .withMessage('Please enter email or phone number')
        .custom(value => {
            const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
            const phoneRegex = /^[\d\s\-\+\(\)]+$/;
            const digitsOnly = value.replace(/\D/g, '');

            const isValidEmail = emailRegex.test(value);
            const isValidPhone = phoneRegex.test(value) && digitsOnly.length >= 10;

            if (!isValidEmail && !isValidPhone) {
                throw new Error('Please enter a valid email address or phone number');
            }
            return true;
        }),
    body('password').notEmpty().withMessage('Password is required')
], async (req, res) => {
    try {
        // Check for validation errors
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: errors.array()
            });
        }

        const { loginInput, password } = req.body;

        // Detect if input is email or phone
        const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
        const isEmail = emailRegex.test(loginInput);

        let user;

        if (isEmail) {
            user = await User.findOne({ email: loginInput });
        } else {
            const phoneCandidates = getPhoneLoginCandidates(loginInput);
            user = await findByPhone(User, phoneCandidates);

            // A lab's contact phone can differ from its owner's user phone.
            // In that case, authenticate the owner account with the lab phone.
            if (!user) {
                const lab = await findByPhone(Lab, phoneCandidates);
                const labOwner = lab?.ownerId ? await User.findById(lab.ownerId) : null;
                user = labOwner?.role === 'lab' ? labOwner : null;
            }
        }

        if (!user) {
            return res.status(401).json({
                success: false,
                message: isEmail ? 'Invalid email or password' : 'Invalid phone number or password'
            });
        }

        // Patients register/log in with phone only; email login is reserved for
        // admin/lab/nurse dashboard accounts.
        if (isEmail && user.role === 'patient') {
            return res.status(400).json({
                success: false,
                message: 'Please log in with your phone number instead of email'
            });
        }

        // Check password
        const isPasswordValid = await bcrypt.compare(password, user.password);
        if (!isPasswordValid) {
            return res.status(401).json({
                success: false,
                message: isEmail ? 'Invalid email or password' : 'Invalid phone number or password'
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

        // Generate JWT token
        const token = jwt.sign(
            { userId: user._id, email: user.email, role: user.role },
            process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788',
            { expiresIn: process.env.JWT_EXPIRES_IN || '10y' }
        );

        // Set token in cookie for page access
        res.cookie('token', token, {
            httpOnly: true,
            secure: process.env.NODE_ENV === 'production',
            sameSite: 'lax',
            maxAge: 30 * 24 * 60 * 60 * 1000 // 30 days
        });

        // Return success response (don't include password)
        res.json({
            success: true,
            message: 'Login successful',
            token,
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                phone: user.phone,
                city: user.city,
                gender: user.gender,
                role: user.role,
                birthDate: user.birthDate,
                profilePicture: user.profilePicture,
                defaultLocation: user.defaultLocation || null,
                // Include nurse rating fields if user is a nurse
                ...(user.role === 'nurse' && {
                    averageRating: user.averageRating || 0,
                    totalRatings: user.totalRatings || 0,
                    nurseCommissionRate: user.nurseCommissionRate
                })
            }
        });

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error during login',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

// Get current user endpoint (protected)
router.get('/me', async (req, res) => {
    try {
        // Get token from header
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'No token provided'
            });
        }

        const token = authHeader.substring(7);

        // Verify token
        const decoded = jwt.verify(
            token,
            process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788',
        );

        // Get user from database
        const user = await User.findById(decoded.userId).select('-password');
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
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

        res.json({
            success: true,
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                phone: user.phone,
                city: user.city,
                gender: user.gender,
                role: user.role,
                birthDate: user.birthDate,
                profilePicture: user.profilePicture,
                defaultLocation: user.defaultLocation || null,
                // Include nurse rating fields if user is a nurse
                ...(user.role === 'nurse' && {
                    averageRating: user.averageRating || 0,
                    totalRatings: user.totalRatings || 0,
                    nurseCommissionRate: user.nurseCommissionRate
                })
            }
        });

    } catch (error) {
        console.error('Get user error:', error);
        if (error.name === 'JsonWebTokenError') {
            return res.status(401).json({
                success: false,
                message: 'Invalid token'
            });
        }
        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({
                success: false,
                message: 'Token expired'
            });
        }
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

// Logout endpoint (POST for AJAX calls)
router.post('/logout', (req, res) => {
    res.clearCookie('token');
    res.json({
        success: true,
        message: 'Logged out successfully'
    });
});

// Logout endpoint (GET for direct links)
router.get('/logout', (req, res) => {
    res.clearCookie('token');
    res.redirect('/');
});

// ============================================================================
// OTP Endpoints
// ============================================================================

/**
 * Register with OTP verification
 * POST /api/auth/register-with-otp
 * Creates a new user after OTP verification
 */
router.post('/register-with-otp', [
    body('name').trim().notEmpty().withMessage('Name is required'),
    body('email').optional({ checkFalsy: true }).isEmail().withMessage('Invalid email format').normalizeEmail(),
    body('phone').trim().notEmpty().withMessage('Phone number is required').custom(value => {
        const phoneRegex = /^[\d\s\-\+\(\)]+$/;
        if (!phoneRegex.test(value) || value.replace(/\D/g, '').length < 10) {
            throw new Error('Invalid phone number format');
        }
        return true;
    }),
    body('city').trim().notEmpty().withMessage('City is required').isIn(VALID_CITIES).withMessage('Invalid city'),
    body('gender').isIn(['male', 'female']).withMessage('Gender must be male or female'),
    body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters long'),
    body('birthDate').notEmpty().withMessage('Birth date is required'),
    body('code').trim().isLength({ min: 4, max: 6 }).withMessage('Invalid OTP code'),
    body('messageId').optional(),
], async (req, res) => {
    try {
        // Check for validation errors
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: errors.array()
            });
        }

        const { name, email, phone, city, gender, password, birthDate, code } = req.body;

        // Check if user already exists (only relevant when an email was provided)
        if (email) {
            const existingUser = await User.findOne({ email });
            if (existingUser) {
                return res.status(409).json({
                    success: false,
                    message: 'User with this email already exists'
                });
            }
        }

        // Check if phone number already exists, under any equivalent format
        const existingPhone = await findByPhone(User, getPhoneLoginCandidates(phone));
        if (existingPhone) {
            return res.status(409).json({
                success: false,
                message: 'User with this phone number already exists'
            });
        }

        // Verify the OTP the user just typed in (no User document exists yet, so this
        // checks the pending-registration cache keyed by phone — see otpService.js)
        const verifyResult = otpService.verifyOtpLocal({ phone, code });

        if (!verifyResult.success) {
            return res.status(400).json({
                success: false,
                message: verifyResult.message || 'Invalid OTP code',
            });
        }

        // OTP verified - create user
        const salt = await bcrypt.genSalt(12);
        const hashedPassword = await bcrypt.hash(password, salt);

        const user = new User(buildPublicPatient({
            name,
            email,
            phone,
            city,
            gender,
            birthDate
        }, hashedPassword, { phoneVerified: true }));

        await user.save();

        // Generate JWT token
        const token = jwt.sign(
            { userId: user._id, email: user.email, role: user.role },
            process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788',
            { expiresIn: process.env.JWT_EXPIRES_IN || '10y' }
        );

        // Return success response (don't include password)
        res.status(201).json({
            success: true,
            message: 'User registered successfully',
            token,
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                phone: user.phone,
                city: user.city,
                gender: user.gender,
                role: user.role,
                birthDate: user.birthDate,
                phoneVerified: user.phoneVerified,
            }
        });

    } catch (error) {
        console.error('Register with OTP error:', error);
        console.error('Error stack:', error.stack);
        res.status(500).json({
            success: false,
            message: 'Server error during registration',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined,
            stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
        });
    }
});

/**
 * Send OTP for phone verification
 * POST /api/auth/send-otp
 */
router.post('/send-otp', [
    body('phone').trim().notEmpty().withMessage('Phone number is required').custom(value => {
        const phoneRegex = /^[\d\s\-\+\(\)]+$/;
        if (!phoneRegex.test(value) || value.replace(/\D/g, '').length < 10) {
            throw new Error('Invalid phone number format');
        }
        return true;
    }),
    body('purpose').optional().isIn(['register', 'login', 'reset']).withMessage('Invalid purpose'),
], async (req, res) => {
    try {
        // Check for validation errors
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: errors.array()
            });
        }

        const { phone, purpose = 'register' } = req.body;

        // Find user by phone, trying every equivalent format (raw/local/
        // international) - not just an exact match on however this
        // particular number happens to be stored from registration.
        const user = await findByPhone(User, getPhoneLoginCandidates(phone));

        // For registration, phone should not exist
        if (purpose === 'register' && user) {
            return res.status(409).json({
                success: false,
                message: 'Phone number already registered'
            });
        }

        // For login/reset, phone should exist
        if ((purpose === 'login' || purpose === 'reset') && !user) {
            return res.status(404).json({
                success: false,
                message: 'Phone number not found'
            });
        }

        // Check resend cooldown
        if (user && user.lastOtpSentAt && !otpService.canResendOtp(user.lastOtpSentAt)) {
            const cooldown = otpService.getResendCooldown(user.lastOtpSentAt);
            return res.status(429).json({
                success: false,
                message: `Please wait ${cooldown} seconds before resending`,
                cooldown
            });
        }

        // Generate and deliver OTP via OTPiq (WhatsApp)
        const otpResult = await otpService.sendOtp(phone);

        if (!otpResult.success) {
            return res.status(500).json({
                success: false,
                message: otpResult.message || 'Failed to send OTP'
            });
        }

        // Update user with OTP details (registration has no user yet — the code is
        // held in otpService's pending-registration cache instead, see otpService.js)
        const otpExpiry = new Date(Date.now() + otpService.OTP_EXPIRY_MINUTES * 60 * 1000);

        if (user) {
            user.otpCode = otpResult.code;
            user.otpMessageId = otpResult.messageId;
            user.otpExpiry = otpExpiry;
            user.lastOtpSentAt = new Date();
            user.verificationAttempts = 0;
            await user.save();
        }

        res.json({
            success: true,
            message: 'OTP sent successfully',
            messageId: otpResult.messageId,
            expiresIn: otpService.OTP_EXPIRY_MINUTES * 60, // seconds
            purpose,
        });

    } catch (error) {
        console.error('Send OTP error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error during OTP send',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * Verify OTP code
 * POST /api/auth/verify-otp
 */
router.post('/verify-otp', [
    body('phone').trim().notEmpty().withMessage('Phone number is required'),
    body('code').trim().isLength({ min: 4, max: 6 }).withMessage('Invalid OTP code'),
    body('messageId').optional(),
], async (req, res) => {
    try {
        // Check for validation errors
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: errors.array()
            });
        }

        const { phone, code, purpose = 'register' } = req.body;

        // Find user by phone, trying every equivalent format
        const user = await findByPhone(User, getPhoneLoginCandidates(phone));

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Check verification attempts
        if (user.verificationAttempts >= otpService.MAX_ATTEMPTS) {
            return res.status(429).json({
                success: false,
                message: 'Maximum verification attempts exceeded. Please request a new OTP.'
            });
        }

        // Verify the OTP locally against the code stored on this user
        const verifyResult = otpService.verifyOtpLocal({ phone, storedCode: user.otpCode, storedExpiry: user.otpExpiry, code });

        // Increment attempts
        user.verificationAttempts += 1;

        if (verifyResult.success) {
            // OTP verified successfully
            user.phoneVerified = true;
            user.otpCode = null;
            user.otpExpiry = null;
            user.otpMessageId = null;
            user.verificationAttempts = 0;
            user.lastOtpSentAt = null;
            await user.save();

            // Generate JWT token
            const token = jwt.sign(
                { userId: user._id, email: user.email, role: user.role },
                process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788',
                { expiresIn: process.env.JWT_EXPIRES_IN || '10y' }
            );

            res.json({
                success: true,
                message: 'OTP verified successfully',
                token,
                user: {
                    id: user._id,
                    name: user.name,
                    email: user.email,
                    phone: user.phone,
                    city: user.city,
                    gender: user.gender,
                    role: user.role,
                    birthDate: user.birthDate,
                    phoneVerified: user.phoneVerified,
                    // Include nurse rating fields if user is a nurse
                    ...(user.role === 'nurse' && {
                        averageRating: user.averageRating || 0,
                        totalRatings: user.totalRatings || 0,
                        nurseCommissionRate: user.nurseCommissionRate
                    })
                }
            });
        } else {
            await user.save();
            const remainingAttempts = otpService.MAX_ATTEMPTS - user.verificationAttempts;
            return res.status(400).json({
                success: false,
                message: verifyResult.message || 'Invalid OTP code',
                remainingAttempts,
            });
        }

    } catch (error) {
        console.error('Verify OTP error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error during OTP verification',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * Resend OTP
 * POST /api/auth/resend-otp
 */
router.post('/resend-otp', [
    body('phone').trim().notEmpty().withMessage('Phone number is required'),
], async (req, res) => {
    try {
        // Check for validation errors
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: errors.array()
            });
        }

        const { phone, purpose = 'register' } = req.body;

        // Find user by phone, trying every equivalent format. Registration has
        // no User document yet - the code is held in otpService's
        // pending-registration cache instead, see otpService.js (same rule
        // /send-otp already follows).
        const user = await findByPhone(User, getPhoneLoginCandidates(phone));

        if (!user && purpose !== 'register') {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Check resend cooldown
        if (user && user.lastOtpSentAt && !otpService.canResendOtp(user.lastOtpSentAt)) {
            const cooldown = otpService.getResendCooldown(user.lastOtpSentAt);
            return res.status(429).json({
                success: false,
                message: `Please wait ${cooldown} seconds before resending`,
                cooldown
            });
        }

        // Generate and deliver a new OTP via OTPiq (WhatsApp)
        const otpResult = await otpService.sendOtp(phone);

        if (!otpResult.success) {
            return res.status(500).json({
                success: false,
                message: otpResult.message || 'Failed to send OTP'
            });
        }

        // Update user with new OTP details
        const otpExpiry = new Date(Date.now() + otpService.OTP_EXPIRY_MINUTES * 60 * 1000);
        if (user) {
            user.otpCode = otpResult.code;
            user.otpMessageId = otpResult.messageId;
            user.otpExpiry = otpExpiry;
            user.lastOtpSentAt = new Date();
            user.verificationAttempts = 0;
            await user.save();
        }

        res.json({
            success: true,
            message: 'OTP resent successfully',
            messageId: otpResult.messageId,
            expiresIn: otpService.OTP_EXPIRY_MINUTES * 60, // seconds
        });

    } catch (error) {
        console.error('Resend OTP error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error during OTP resend',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

// ============================================================================
// Password Reset Endpoints
// ============================================================================

/**
 * Request password reset - sends OTP to phone
 * POST /api/auth/password-reset/request
 */
router.post('/password-reset/request', [
    body('phone').trim().notEmpty().withMessage('Phone number is required').custom(value => {
        const phoneRegex = /^[\d\s\-\+\(\)]+$/;
        if (!phoneRegex.test(value) || value.replace(/\D/g, '').length < 10) {
            throw new Error('Invalid phone number format');
        }
        return true;
    }),
], async (req, res) => {
    try {
        // Check for validation errors
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: errors.array()
            });
        }

        const { phone } = req.body;

        // Find user by phone, trying every equivalent format
        const user = await findByPhone(User, getPhoneLoginCandidates(phone));

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'Phone number not found'
            });
        }

        // Check resend cooldown
        if (user.lastOtpSentAt && !otpService.canResendOtp(user.lastOtpSentAt)) {
            const cooldown = otpService.getResendCooldown(user.lastOtpSentAt);
            return res.status(429).json({
                success: false,
                message: `Please wait ${cooldown} seconds before resending`,
                cooldown
            });
        }

        // Generate and deliver OTP via OTPiq (WhatsApp)
        const otpResult = await otpService.sendPasswordResetOtp(phone);

        if (!otpResult.success) {
            return res.status(500).json({
                success: false,
                message: otpResult.message || 'Failed to send OTP'
            });
        }

        // Update user with OTP details
        const otpExpiry = new Date(Date.now() + otpService.OTP_EXPIRY_MINUTES * 60 * 1000);
        user.otpCode = otpResult.code;
        user.otpMessageId = otpResult.messageId;
        user.otpExpiry = otpExpiry;
        user.lastOtpSentAt = new Date();
        user.verificationAttempts = 0;
        await user.save();

        res.json({
            success: true,
            message: 'OTP sent successfully',
            messageId: otpResult.messageId,
            expiresIn: otpService.OTP_EXPIRY_MINUTES * 60, // seconds
        });

    } catch (error) {
        console.error('Password reset request error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error during password reset request',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * Verify OTP for password reset - returns reset token
 * POST /api/auth/password-reset/verify-otp
 */
router.post('/password-reset/verify-otp', [
    body('phone').trim().notEmpty().withMessage('Phone number is required'),
    body('code').trim().isLength({ min: 4, max: 6 }).withMessage('Invalid OTP code'),
    body('messageId').optional(),
], async (req, res) => {
    try {
        // Check for validation errors
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: errors.array()
            });
        }

        const { phone, code } = req.body;

        // Find user by phone, trying every equivalent format
        const user = await findByPhone(User, getPhoneLoginCandidates(phone));

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Check verification attempts
        if (user.verificationAttempts >= otpService.MAX_ATTEMPTS) {
            return res.status(429).json({
                success: false,
                message: 'Maximum verification attempts exceeded. Please request a new OTP.'
            });
        }

        // Verify the OTP locally against the code stored on this user
        const verifyResult = otpService.verifyOtpLocal({ phone, storedCode: user.otpCode, storedExpiry: user.otpExpiry, code });

        // Increment attempts
        user.verificationAttempts += 1;

        if (verifyResult.success) {
            // Generate reset token (valid for 15 minutes)
            const resetToken = jwt.sign(
                { userId: user._id, type: 'password_reset' },
                process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788',
                { expiresIn: '15m' }
            );

            // Clear OTP data
            user.otpCode = null;
            user.otpExpiry = null;
            user.otpMessageId = null;
            user.verificationAttempts = 0;
            user.lastOtpSentAt = null;
            await user.save();

            res.json({
                success: true,
                message: 'OTP verified successfully',
                resetToken
            });
        } else {
            await user.save();
            const remainingAttempts = otpService.MAX_ATTEMPTS - user.verificationAttempts;
            return res.status(400).json({
                success: false,
                message: verifyResult.message || 'Invalid OTP code',
                remainingAttempts,
            });
        }

    } catch (error) {
        console.error('Password reset verify OTP error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error during OTP verification',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * Confirm password reset with new password
 * POST /api/auth/password-reset/confirm
 */
router.post('/password-reset/confirm', [
    body('resetToken').trim().notEmpty().withMessage('Reset token is required'),
    body('newPassword').isLength({ min: 8 }).withMessage('Password must be at least 8 characters long'),
], async (req, res) => {
    try {
        // Check for validation errors
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: errors.array()
            });
        }

        const { resetToken, newPassword } = req.body;

        // Verify reset token
        let decoded;
        try {
            decoded = jwt.verify(
                resetToken,
                process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788'
            );
        } catch (err) {
            return res.status(401).json({
                success: false,
                message: 'Invalid or expired reset token'
            });
        }

        // Check if this is a password reset token
        if (decoded.type !== 'password_reset') {
            return res.status(401).json({
                success: false,
                message: 'Invalid token type'
            });
        }

        // Find user by ID
        const user = await User.findById(decoded.userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Hash new password
        const salt = await bcrypt.genSalt(12);
        const hashedPassword = await bcrypt.hash(newPassword, salt);

        // Update password
        user.password = hashedPassword;
        await user.save();

        res.json({
            success: true,
            message: 'Password reset successfully'
        });

    } catch (error) {
        console.error('Password reset confirm error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error during password reset',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * Change password (while logged in)
 * POST /api/auth/change-password
 */
router.post('/change-password', [
    body('currentPassword').notEmpty().withMessage('Current password is required'),
    body('newPassword').isLength({ min: 8 }).withMessage('New password must be at least 8 characters long'),
], async (req, res) => {
    try {
        // Check for validation errors
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: errors.array()
            });
        }

        // Get token from header
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'Authentication required'
            });
        }

        const token = authHeader.split(' ')[1];

        // Verify token
        let decoded;
        try {
            decoded = jwt.verify(
                token,
                process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788'
            );
        } catch (err) {
            return res.status(401).json({
                success: false,
                message: 'Invalid or expired token'
            });
        }

        const { currentPassword, newPassword } = req.body;

        // Find user
        const user = await User.findById(decoded.userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Verify current password
        const isMatch = await bcrypt.compare(currentPassword, user.password);
        if (!isMatch) {
            return res.status(400).json({
                success: false,
                message: 'Current password is incorrect'
            });
        }

        // Hash new password
        const salt = await bcrypt.genSalt(12);
        const hashedPassword = await bcrypt.hash(newPassword, salt);

        // Update password
        user.password = hashedPassword;
        await user.save();

        res.json({
            success: true,
            message: 'Password changed successfully'
        });

    } catch (error) {
        console.error('Change password error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error during password change',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

// ============================================================================
// Profile Update Endpoints
// ============================================================================

/**
 * Update user profile (non-phone fields)
 * PUT /api/auth/update-profile
 */
router.put('/update-profile', [
    body('name').optional().trim().notEmpty().withMessage('Name cannot be empty'),
    body('email').optional().isEmail().withMessage('Invalid email format').normalizeEmail(),
    body('city').optional().isIn(VALID_CITIES).withMessage('Invalid city'),
    body('gender').optional().isIn(['male', 'female']).withMessage('Gender must be male or female'),
    body('birthDate').optional().notEmpty().withMessage('Birth date cannot be empty'),
    body('latitude').optional().isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude'),
    body('longitude').optional().isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude'),
], async (req, res) => {
    try {
        // Get token from header
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'No token provided'
            });
        }

        const token = authHeader.substring(7);

        // Verify token
        let decoded;
        try {
            decoded = jwt.verify(
                token,
                process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788'
            );
        } catch (err) {
            return res.status(401).json({
                success: false,
                message: 'Invalid or expired token'
            });
        }

        // Check for validation errors
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: errors.array()
            });
        }

        const { name, email, city, gender, birthDate, address, landmark, latitude, longitude } = req.body;

        // Find user
        const user = await User.findById(decoded.userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // If email is changing, check if new email is already used
        if (email && email !== user.email) {
            const existingEmail = await User.findOne({ email, _id: { $ne: user._id } });
            if (existingEmail) {
                return res.status(409).json({
                    success: false,
                    message: 'Email is already in use'
                });
            }
        }

        // Update fields
        if (name) user.name = name;
        if (email) user.email = email;
        if (city) user.city = city;
        if (gender) user.gender = gender;
        if (birthDate) user.birthDate = birthDate;

        // Default location (used as the base point for nearest-technician
        // ranking when there's no fresh live GPS position)
        if (latitude !== undefined && longitude !== undefined) {
            user.defaultLocation = {
                ...(user.defaultLocation ? user.defaultLocation.toObject?.() ?? user.defaultLocation : {}),
                address: address !== undefined ? address : user.defaultLocation?.address,
                landmark: landmark !== undefined ? landmark : user.defaultLocation?.landmark,
                coordinates: {
                    latitude: Number(latitude),
                    longitude: Number(longitude),
                },
            };
        }

        await user.save();

        res.json({
            success: true,
            message: 'Profile updated successfully',
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                phone: user.phone,
                city: user.city,
                gender: user.gender,
                role: user.role,
                birthDate: user.birthDate,
                profilePicture: user.profilePicture,
                defaultLocation: user.defaultLocation || null,
                ...(user.role === 'nurse' && {
                    averageRating: user.averageRating || 0,
                    totalRatings: user.totalRatings || 0,
                    nurseCommissionRate: user.nurseCommissionRate
                })
            }
        });

    } catch (error) {
        console.error('Update profile error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error during profile update',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * Upload/replace the logged-in user's profile picture
 * POST /api/auth/profile-picture
 */
router.post('/profile-picture', auth.verifyToken, ...uploadProfilePicture, async (req, res) => {
    try {
        if (!req.file || !req.file.r2Url) {
            return res.status(400).json({
                success: false,
                message: 'No image file provided'
            });
        }

        const user = await User.findById(req.user.id);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Delete the old picture from R2 (best-effort, don't fail the request over it)
        if (user.profilePicture) {
            try {
                await r2Service.deleteFile(user.profilePicture);
            } catch (deleteError) {
                console.error('Error deleting old profile picture:', deleteError);
            }
        }

        user.profilePicture = req.file.r2Url;
        await user.save();

        res.json({
            success: true,
            message: 'Profile picture updated successfully',
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                phone: user.phone,
                city: user.city,
                gender: user.gender,
                role: user.role,
                birthDate: user.birthDate,
                profilePicture: user.profilePicture,
            }
        });
    } catch (error) {
        console.error('Upload profile picture error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error during profile picture upload'
        });
    }
});

/**
 * Send OTP for phone number change
 * POST /api/auth/send-phone-change-otp
 */
router.post('/send-phone-change-otp', [
    body('newPhone').trim().notEmpty().withMessage('New phone number is required').custom(value => {
        const phoneRegex = /^[\d\s\-\+\(\)]+$/;
        if (!phoneRegex.test(value) || value.replace(/\D/g, '').length < 10) {
            throw new Error('Invalid phone number format');
        }
        return true;
    }),
], async (req, res) => {
    try {
        // Get token from header
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'No token provided'
            });
        }

        const token = authHeader.substring(7);

        // Verify token
        let decoded;
        try {
            decoded = jwt.verify(
                token,
                process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788'
            );
        } catch (err) {
            return res.status(401).json({
                success: false,
                message: 'Invalid or expired token'
            });
        }

        // Check for validation errors
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: errors.array()
            });
        }

        const { newPhone } = req.body;

        // Find user
        const user = await User.findById(decoded.userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Check if new phone is same as current (compare every equivalent
        // format, not just an exact string match)
        if (getPhoneLoginCandidates(newPhone).includes(user.phone)) {
            return res.status(400).json({
                success: false,
                message: 'New phone number is same as current'
            });
        }

        // Check if new phone is already registered by another user
        const existingPhone = await findByPhone(
            User,
            getPhoneLoginCandidates(newPhone),
            { _id: { $ne: user._id } }
        );
        if (existingPhone) {
            return res.status(409).json({
                success: false,
                message: 'Phone number is already registered'
            });
        }

        // Check resend cooldown
        if (user.lastOtpSentAt && !otpService.canResendOtp(user.lastOtpSentAt)) {
            const cooldown = otpService.getResendCooldown(user.lastOtpSentAt);
            return res.status(429).json({
                success: false,
                message: `Please wait ${cooldown} seconds before resending`,
                cooldown
            });
        }

        // Generate and deliver OTP to the new phone number via OTPiq (WhatsApp)
        const otpResult = await otpService.sendOtp(newPhone);

        if (!otpResult.success) {
            return res.status(500).json({
                success: false,
                message: otpResult.message || 'Failed to send OTP'
            });
        }

        // Store OTP details and new phone for verification
        const otpExpiry = new Date(Date.now() + otpService.OTP_EXPIRY_MINUTES * 60 * 1000);
        user.otpCode = otpResult.code;
        user.otpMessageId = otpResult.messageId;
        user.otpExpiry = otpExpiry;
        user.lastOtpSentAt = new Date();
        user.verificationAttempts = 0;
        user.pendingPhoneChange = newPhone; // Store the new phone temporarily
        await user.save();

        res.json({
            success: true,
            message: 'OTP sent successfully',
            messageId: otpResult.messageId,
            expiresIn: otpService.OTP_EXPIRY_MINUTES * 60,
        });

    } catch (error) {
        console.error('Send phone change OTP error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error during OTP send',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * Verify OTP and update phone number
 * POST /api/auth/verify-phone-change
 */
router.post('/verify-phone-change', [
    body('code').trim().isLength({ min: 4, max: 6 }).withMessage('Invalid OTP code'),
    body('messageId').optional(),
    body('newPhone').trim().notEmpty().withMessage('New phone number is required'),
], async (req, res) => {
    try {
        // Get token from header
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'No token provided'
            });
        }

        const token = authHeader.substring(7);

        // Verify token
        let decoded;
        try {
            decoded = jwt.verify(
                token,
                process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788'
            );
        } catch (err) {
            return res.status(401).json({
                success: false,
                message: 'Invalid or expired token'
            });
        }

        // Check for validation errors
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                success: false,
                message: 'Validation failed',
                errors: errors.array()
            });
        }

        const { code, newPhone } = req.body;

        // Find user
        const user = await User.findById(decoded.userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Check verification attempts
        if (user.verificationAttempts >= otpService.MAX_ATTEMPTS) {
            return res.status(429).json({
                success: false,
                message: 'Maximum verification attempts exceeded. Please request a new OTP.'
            });
        }

        // Verify the OTP locally against the code stored on this user
        const verifyResult = otpService.verifyOtpLocal({ phone: newPhone, storedCode: user.otpCode, storedExpiry: user.otpExpiry, code });

        // Increment attempts
        user.verificationAttempts += 1;

        if (verifyResult.success) {
            // OTP verified - update phone number
            user.phone = newPhone;
            user.phoneVerified = true;
            user.otpCode = null;
            user.otpExpiry = null;
            user.otpMessageId = null;
            user.verificationAttempts = 0;
            user.lastOtpSentAt = null;
            user.pendingPhoneChange = null;
            await user.save();

            res.json({
                success: true,
                message: 'Phone number updated successfully',
                user: {
                    id: user._id,
                    name: user.name,
                    email: user.email,
                    phone: user.phone,
                    city: user.city,
                    gender: user.gender,
                    role: user.role,
                    birthDate: user.birthDate,
                    phoneVerified: user.phoneVerified,
                    ...(user.role === 'nurse' && {
                        averageRating: user.averageRating || 0,
                        totalRatings: user.totalRatings || 0,
                        nurseCommissionRate: user.nurseCommissionRate
                    })
                }
            });
        } else {
            await user.save();
            const remainingAttempts = otpService.MAX_ATTEMPTS - user.verificationAttempts;
            return res.status(400).json({
                success: false,
                message: verifyResult.message || 'Invalid OTP code',
                remainingAttempts,
            });
        }

    } catch (error) {
        console.error('Verify phone change error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error during OTP verification',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

/**
 * Delete user account
 * DELETE /api/auth/delete-account
 */
router.delete('/delete-account', [
    body('password').optional().notEmpty().withMessage('Password is required for confirmation'),
], async (req, res) => {
    try {
        // Get token from header
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'No token provided'
            });
        }

        const token = authHeader.substring(7);

        // Verify token
        let decoded;
        try {
            decoded = jwt.verify(
                token,
                process.env.JWT_SECRET || 'b668e17f80f60ae673dada6b29fb1b3c3350f52bcca47a919504c2f9713ef761d9776f53afa38581b3b9e1f0954e9f39a8fd8c7ac21596464e56c1a98a583788'
            );
        } catch (err) {
            return res.status(401).json({
                success: false,
                message: 'Invalid or expired token'
            });
        }

        // Find user
        const user = await User.findById(decoded.userId);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Optional: Verify password if provided
        const { password } = req.body;
        if (password) {
            const isPasswordValid = await bcrypt.compare(password, user.password);
            if (!isPasswordValid) {
                return res.status(401).json({
                    success: false,
                    message: 'Invalid password'
                });
            }
        }

        // Delete the user
        await User.findByIdAndDelete(decoded.userId);

        res.json({
            success: true,
            message: 'Account deleted successfully'
        });

    } catch (error) {
        console.error('Delete account error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error during account deletion',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
});

module.exports = router;
