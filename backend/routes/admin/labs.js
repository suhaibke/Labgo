const express = require('express');
const multer = require('multer');
const router = express.Router();
const Lab = require('../../models/Lab');
const User = require('../../models/User');
const { verifyToken } = require('../../middleware/auth');
const { r2SingleUpload, r2LabRegistrationUpload } = require('../../middleware/r2Upload');
const r2Service = require('../../services/r2Service');
const {
    LAB_DOCUMENT_DEFINITIONS,
    LAB_DOCUMENT_FIELDS,
    buildLabDocuments,
    getUploadedFileUrls,
    getStoredDocumentUrls
} = require('../../helpers/lab-documents');
const {
    MAX_IMPORT_ROWS,
    addImportedTests,
    buildLabTest,
    buildTestsTemplate,
    readTestRows
} = require('../../helpers/lab-tests');

// R2 upload middleware for lab logos
const uploadLabLogo = r2SingleUpload('labs', 'logo', 'lab-logo-');
const uploadLabRegistration = r2LabRegistrationUpload([
    { name: 'logo', maxCount: 1 },
    ...LAB_DOCUMENT_FIELDS.map(name => ({
        name,
        maxCount: LAB_DOCUMENT_DEFINITIONS[name].maxCount
    }))
]);

// Spreadsheets are parsed in memory and never stored
const testImportUpload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (req, file, cb) => cb(null, /\.xlsx?$/i.test(file.originalname))
}).single('file');

const acceptTestImport = (req, res, next) => {
    testImportUpload(req, res, error => {
        if (error) {
            return res.status(400).json({ success: false, message: 'Invalid file', code: 'invalidFile' });
        }
        next();
    });
};

async function deleteUploadedFiles(files) {
    await Promise.all(getUploadedFileUrls(files).map(url => r2Service.deleteFile(url)));
}

// Admin role verification middleware for API routes
const adminOnly = async (req, res, next) => {
    if (req.userRole !== 'admin') {
        return res.status(403).json({
            success: false,
            message: 'Access denied. Admin role required.'
        });
    }
    next();
};

// Get all labs with detailed information
router.get('/', verifyToken, adminOnly, async (req, res) => {
    try {
        const { page = 1, limit = 10, search, status, city, country } = req.query;
        const skip = (page - 1) * limit;

        // Build query
        let query = {};

        if (search) {
            query.$or = [
                { name: { $regex: search, $options: 'i' } },
                { email: { $regex: search, $options: 'i' } },
                { phone: { $regex: search, $options: 'i' } }
            ];
        }

        if (status) {
            query.status = status;
        }

        if (city) {
            query.city = { $regex: city, $options: 'i' };
        }

        if (country) {
            query.country = { $regex: country, $options: 'i' };
        }

        const labs = await Lab.find(query)
            .populate('ownerId', 'name email')
            .populate('createdBy', 'name')
            .populate('lastUpdatedBy', 'name')
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(parseInt(limit));

        const total = await Lab.countDocuments(query);

        // Get statistics
        const stats = await Lab.aggregate([
            {
                $group: {
                    _id: '$status',
                    count: { $sum: 1 }
                }
            }
        ]);

        res.json({
            success: true,
            data: labs,
            total,
            page: parseInt(page),
            pages: Math.ceil(total / limit),
            stats
        });
    } catch (error) {
        console.error('Error fetching labs:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch labs' });
    }
});

// Get all users who can be lab owners (excluding existing lab owners)
router.get('/available-owners', verifyToken, adminOnly, async (req, res) => {
    try {
        const { search } = req.query;

        // Get users who are not already lab owners
        const existingLabOwners = await Lab.distinct('ownerId');

        let query = {
            _id: { $nin: existingLabOwners },
            role: { $in: ['patient', 'nurse'] }
        };

        if (search) {
            query.$or = [
                { name: { $regex: search, $options: 'i' } },
                { email: { $regex: search, $options: 'i' } }
            ];
        }

        const users = await User.find(query)
            .select('name email role createdAt')
            .sort({ createdAt: -1 })
            .limit(50);

        res.json({
            success: true,
            data: users
        });
    } catch (error) {
        console.error('Error fetching available owners:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch available owners' });
    }
});

// Search owner by email
router.get('/search-owner', verifyToken, adminOnly, async (req, res) => {
    try {
        const { email } = req.query;

        if (!email) {
            return res.status(400).json({
                success: false,
                message: 'Email parameter is required'
            });
        }

        // Find users by email or name (supports partial search)
        const users = await User.find({
            $or: [
                { email: { $regex: email, $options: 'i' } },
                { name: { $regex: email, $options: 'i' } }
            ],
            role: { $in: ['patient', 'nurse'] } // Only show users who can be lab owners
        }).select('name email role phone createdAt')
        .limit(10); // Limit results to avoid overwhelming the UI

        if (!users || users.length === 0) {
            return res.json({
                success: false,
                message: 'No users found',
                users: []
            });
        }

        res.json({
            success: true,
            message: `${users.length} user(s) found`,
            users: users
        });
    } catch (error) {
        console.error('Error searching owner by email:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to search owner'
        });
    }
});

// Get lab by ID with all patient tests
router.get('/:id', verifyToken, adminOnly, async (req, res) => {
    try {
        const lab = await Lab.findById(req.params.id)
            .select('+documents')
            .populate('ownerId', 'name email phone gender birthDate role createdAt')
            .populate('createdBy', 'name')
            .populate('lastUpdatedBy', 'name')
            .populate('patientTests.patientId', 'name email');

        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }

        // Get lab statistics
        const recentTests = lab.patientTests
            .sort((a, b) => new Date(b.requestDate) - new Date(a.requestDate))
            .slice(0, 10);

        res.json({
            success: true,
            data: lab,
            recentTests,
            totalTests: lab.patientTests.length,
            completedTests: lab.patientTests.filter(test => test.status === 'Completed').length,
            pendingTests: lab.patientTests.filter(test => test.status === 'Pending').length
        });
    } catch (error) {
        console.error('Error fetching lab:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch lab' });
    }
});

// Stream a private registration document to an authenticated admin.
router.get('/:id/documents/:category/:documentId', verifyToken, adminOnly, async (req, res) => {
    try {
        const { category, documentId } = req.params;

        if (!LAB_DOCUMENT_FIELDS.includes(category)) {
            return res.status(400).json({ success: false, message: 'Invalid document category' });
        }

        const lab = await Lab.findById(req.params.id).select('+documents');
        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }

        const document = (lab.documents?.[category] || []).find(
            item => String(item._id) === documentId
        );

        if (!document) {
            return res.status(404).json({ success: false, message: 'Document not found' });
        }

        const fileData = await r2Service.getFileStream(document.url);
        if (!fileData?.stream) {
            return res.status(404).json({ success: false, message: 'Document file not found' });
        }

        const originalName = document.originalName || 'lab-document';
        const asciiName = originalName
            .replace(/["\\\r\n]/g, '_')
            .replace(/[^\x20-\x7E]/g, '_');

        res.set('Content-Type', fileData.contentType || document.mimeType || 'application/octet-stream');
        res.set('Content-Disposition', `inline; filename="${asciiName}"; filename*=UTF-8''${encodeURIComponent(originalName)}`);
        res.set('Cache-Control', 'private, no-store');
        res.set('X-Content-Type-Options', 'nosniff');
        if (fileData.contentLength) {
            res.set('Content-Length', String(fileData.contentLength));
        }

        fileData.stream.pipe(res);
    } catch (error) {
        console.error('Error streaming lab document:', error);
        if (!res.headersSent) {
            res.status(500).json({ success: false, message: 'Failed to load document' });
        }
    }
});

// Create new lab
router.post('/', verifyToken, adminOnly, ...uploadLabRegistration, async (req, res) => {
    let labSaved = false;

    try {
        const labData = { ...req.body };
        delete labData.documents;

        // Handle file upload to R2
        const logoFile = req.files?.logo?.[0];
        if (logoFile?.r2Url) {
            labData.logo = logoFile.r2Url;
        }
        labData.documents = buildLabDocuments(req.files);

        // Parse JSON strings that came from FormData
        if (labData.operatingHours && typeof labData.operatingHours === 'string') {
            try {
                labData.operatingHours = JSON.parse(labData.operatingHours);
            } catch (e) {
                console.error('Error parsing operatingHours:', e);
            }
        }

        // Parse specializations array if it exists as JSON string
        if (labData.specialization && typeof labData.specialization === 'string') {
            try {
                labData.specialization = JSON.parse(labData.specialization);
            } catch (e) {
                console.error('Error parsing specialization:', e);
            }
        }

        // Parse map coordinates if provided as JSON string
        if (labData.coordinates && typeof labData.coordinates === 'string') {
            try {
                const parsed = JSON.parse(labData.coordinates);
                const lat = parseFloat(parsed.latitude);
                const lng = parseFloat(parsed.longitude);
                labData.coordinates = (!isNaN(lat) && !isNaN(lng)) ? { latitude: lat, longitude: lng } : undefined;
            } catch (e) {
                console.error('Error parsing coordinates:', e);
                labData.coordinates = undefined;
            }
        }

        // Set required fields
        labData.createdBy = req.user.id || req.userId;
        labData.lastUpdatedBy = req.user.id || req.userId;

        // Address should remain as a string (Lab model expects String type)
        // No need to convert to object since the frontend sends it as a string

        // If ownerId is provided and user exists, update user role to 'lab'
        if (!labData.ownerId) {
            await deleteUploadedFiles(req.files);
            return res.status(400).json({ success: false, message: 'Lab owner is required' });
        }

        const user = await User.findById(labData.ownerId);
        if (!user) {
            await deleteUploadedFiles(req.files);
            return res.status(400).json({ success: false, message: 'Lab owner not found' });
        }

        // Use updateOne to bypass validation on existing user documents.
        await User.updateOne(
            { _id: labData.ownerId },
            { role: 'lab' }
        );

        const lab = new Lab(labData);
        await lab.save();
        labSaved = true;

        await Lab.findById(lab._id)
            .select('+documents')
            .populate('ownerId', 'name email')
            .populate('createdBy', 'name')
            .then(populatedLab => {
                res.status(201).json({
                    success: true,
                    message: 'Lab created successfully',
                    data: populatedLab
                });
            });
    } catch (error) {
        console.error('Error creating lab:', error);
        if (!labSaved) {
            await deleteUploadedFiles(req.files);
        }
        if (error.code === 11000) {
            return res.status(400).json({
                success: false,
                message: 'Lab with this email or phone already exists'
            });
        }
        res.status(500).json({ success: false, message: 'Failed to create lab' });
    }
});

// Update lab
router.put('/:id', verifyToken, adminOnly, ...uploadLabLogo, async (req, res) => {
    try {
        const lab = await Lab.findById(req.params.id);

        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }

        const oldOwnerId = lab.ownerId;
        const newOwnerId = req.body.ownerId;

        // Handle logo upload to R2
        if (req.file && req.file.r2Url) {
            // Delete old logo from R2 if exists
            if (lab.logo) {
                await r2Service.deleteFile(lab.logo);
            }
            lab.logo = req.file.r2Url;
        }

        // Update basic fields
        if (req.body.name) lab.name = req.body.name;
        if (req.body.email) lab.email = req.body.email;
        if (req.body.phone) lab.phone = req.body.phone;
        if (req.body.website) lab.website = req.body.website;
        if (req.body.address) lab.address = req.body.address;
        if (req.body.city) lab.city = req.body.city;
        if (req.body.zone) lab.zone = req.body.zone;
        if (req.body.country) lab.country = req.body.country;
        if (req.body.status) lab.status = req.body.status;

        // Update map coordinates if provided as JSON string
        if (req.body.coordinates) {
            try {
                const parsed = JSON.parse(req.body.coordinates);
                const lat = parseFloat(parsed.latitude);
                const lng = parseFloat(parsed.longitude);
                if (!isNaN(lat) && !isNaN(lng)) {
                    lab.coordinates = { latitude: lat, longitude: lng };
                }
            } catch (e) {
                console.error('Error parsing coordinates:', e);
            }
        }
        
        // Update commission rate (lab percentage - what lab keeps)
        if (req.body.commissionRate !== undefined) {
            const rate = parseFloat(req.body.commissionRate);
            if (!isNaN(rate) && rate >= 0 && rate <= 100) {
                lab.commissionRate = rate;
            }
        }

        // Handle specialization - filter valid enum values
        if (req.body.specialization) {
            let specializations = [];
            try {
                specializations = JSON.parse(req.body.specialization);
            } catch (e) {
                specializations = req.body.specialization;
            }

            // Ensure it's an array and filter valid enum values
            if (Array.isArray(specializations)) {
                const validSpecializations = ['Blood Tests', 'X-Ray', 'MRI', 'CT Scan', 'Ultrasound', 'Pathology', 'Microbiology', 'Biochemistry', 'Genetics', 'Allergy', 'Cardiology', 'Neurology', 'General'];
                lab.specialization = specializations.filter(spec => validSpecializations.includes(spec));
            }
        }

        lab.lastUpdatedBy = req.user.id;

        await lab.save();

        // Handle owner role changes
        if (oldOwnerId && oldOwnerId.toString() !== newOwnerId) {
            // Remove lab role from old owner
            await User.findByIdAndUpdate(oldOwnerId, { role: 'patient' });

            // Assign lab role to new owner
            if (newOwnerId) {
                await User.findByIdAndUpdate(newOwnerId, { role: 'lab' });
            }
        }

        await Lab.findById(lab._id)
            .populate('ownerId', 'name email phone gender birthDate role createdAt')
            .populate('lastUpdatedBy', 'name')
            .then(populatedLab => {
                res.json({
                    success: true,
                    message: 'Lab updated successfully',
                    data: populatedLab
                });
            });
    } catch (error) {
        console.error('Error updating lab:', error);
        if (error.code === 11000) {
            return res.status(400).json({
                success: false,
                message: 'Lab with this email or phone already exists'
            });
        }
        res.status(500).json({ success: false, message: 'Failed to update lab' });
    }
});

// Delete lab
router.delete('/:id', verifyToken, adminOnly, async (req, res) => {
    try {
        const lab = await Lab.findById(req.params.id).select('+documents');

        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }

        // Remove lab role from owner
        if (lab.ownerId) {
            await User.findByIdAndUpdate(lab.ownerId, { role: 'patient' });
        }

        await Lab.findByIdAndDelete(req.params.id);

        const storedFiles = [lab.logo, ...getStoredDocumentUrls(lab.documents)].filter(Boolean);
        await Promise.all(storedFiles.map(url => r2Service.deleteFile(url)));

        res.json({
            success: true,
            message: 'Lab deleted successfully'
        });
    } catch (error) {
        console.error('Error deleting lab:', error);
        res.status(500).json({ success: false, message: 'Failed to delete lab' });
    }
});

// Show or hide the "Powered by LabGo" footer on this lab's result reports.
// Platform admins only (labs cannot change it from their settings).
router.patch('/:id/report-branding', verifyToken, adminOnly, async (req, res) => {
    try {
        if (typeof req.body?.hidePlatformFooter !== 'boolean') {
            return res.status(400).json({ success: false, message: 'hidePlatformFooter must be true or false' });
        }
        const lab = await Lab.findById(req.params.id);
        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }
        lab.reportBranding = {
            hidePlatformFooter: req.body.hidePlatformFooter,
            updatedBy: req.user.id || req.user._id,
            updatedAt: new Date(),
        };
        await lab.save();
        res.json({
            success: true,
            message: req.body.hidePlatformFooter ? 'LabGo footer hidden on reports' : 'LabGo footer shown on reports',
            data: { reportBranding: lab.reportBranding },
        });
    } catch (error) {
        console.error('Error updating report branding:', error);
        res.status(500).json({ success: false, message: 'Failed to update report branding' });
    }
});

// Toggle featured status
router.patch('/:id/featured', verifyToken, adminOnly, async (req, res) => {
    try {
        const lab = await Lab.findById(req.params.id);

        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }

        // Toggle featured status
        lab.isFeatured = !lab.isFeatured;
        lab.featuredAt = lab.isFeatured ? new Date() : null;
        lab.lastUpdatedBy = req.user.id;

        await lab.save();

        res.json({
            success: true,
            message: lab.isFeatured ? 'Lab marked as featured' : 'Lab removed from featured',
            data: {
                isFeatured: lab.isFeatured,
                featuredAt: lab.featuredAt
            }
        });
    } catch (error) {
        console.error('Error toggling featured status:', error);
        res.status(500).json({ success: false, message: 'Failed to update featured status' });
    }
});

// Get lab statistics
router.get('/stats/overview', verifyToken, adminOnly, async (req, res) => {
    try {
        const totalLabs = await Lab.countDocuments();
        const activeLabs = await Lab.countDocuments({ status: 'Active' });
        const inactiveLabs = await Lab.countDocuments({ status: 'Inactive' });
        const pendingLabs = await Lab.countDocuments({ status: 'Pending' });

        const labsByCountry = await Lab.aggregate([
            { $group: { _id: '$country', count: { $sum: 1 } } },
            { $sort: { count: -1 } }
        ]);

        const totalTests = await Lab.aggregate([
            { $unwind: '$patientTests' },
            { $count: 'total' }
        ]);

        const testsByMonth = await Lab.aggregate([
            { $unwind: '$patientTests' },
            {
                $group: {
                    _id: { $dateToString: { format: "%Y-%m", date: "$patientTests.requestDate" } },
                    count: { $sum: 1 }
                }
            },
            { $sort: { _id: 1 } },
            { $limit: 12 }
        ]);

        res.json({
            success: true,
            data: {
                totalLabs,
                activeLabs,
                inactiveLabs,
                pendingLabs,
                labsByCountry,
                totalTests: totalTests[0]?.total || 0,
                testsByMonth
            }
        });
    } catch (error) {
        console.error('Error fetching lab statistics:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch statistics' });
    }
});

// Download the blank Excel template for importing tests
router.get('/tests/template', verifyToken, adminOnly, (req, res) => {
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename="labgo-tests-template.xlsx"');
    res.send(buildTestsTemplate());
});

// Import tests into the lab's catalog from an Excel file
router.post('/:id/tests/import', verifyToken, adminOnly, acceptTestImport, async (req, res) => {
    const reject = code => res.status(400).json({ success: false, message: 'Import rejected', code });

    try {
        if (!req.file) return reject('invalidFile');

        let rows;
        try {
            rows = readTestRows(req.file.buffer);
        } catch (error) {
            return reject('invalidFile');
        }

        if (rows.length === 0) return reject('emptyFile');
        if (rows.length > MAX_IMPORT_ROWS) return reject('tooManyRows');

        const lab = await Lab.findById(req.params.id);

        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }

        const { addedCount, skipped, errors } = addImportedTests(lab, rows);

        if (addedCount > 0) {
            lab.lastUpdatedBy = req.user.id;
            await lab.save();
        }

        res.json({
            success: true,
            results: {
                added: addedCount > 0 ? lab.tests.slice(-addedCount) : [],
                skipped,
                errors
            }
        });
    } catch (error) {
        console.error('Error importing lab tests:', error);
        res.status(500).json({ success: false, message: 'Failed to import tests' });
    }
});

// Add a test to the lab's catalog
router.post('/:id/tests', verifyToken, adminOnly, async (req, res) => {
    try {
        const { test, error } = buildLabTest(req.body);

        if (error) {
            return res.status(400).json({ success: false, message: 'Invalid test data', code: error });
        }

        const lab = await Lab.findById(req.params.id);

        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }

        lab.tests.push(test);
        lab.lastUpdatedBy = req.user.id;

        await lab.save();

        res.status(201).json({
            success: true,
            message: 'Test added successfully',
            data: lab.tests[lab.tests.length - 1]
        });
    } catch (error) {
        console.error('Error adding lab test:', error);
        res.status(500).json({ success: false, message: 'Failed to add test' });
    }
});

// Add patient test to lab
router.post('/:labId/patient-tests', verifyToken, adminOnly, async (req, res) => {
    try {
        const lab = await Lab.findById(req.params.labId);

        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }

        const test = {
            ...req.body,
            requestDate: new Date(req.body.requestDate || Date.now())
        };

        lab.patientTests.push(test);
        lab.totalTestsPerformed = lab.patientTests.length;
        lab.lastUpdatedBy = req.user.id;

        await lab.save();

        res.status(201).json({
            success: true,
            message: 'Patient test added successfully',
            data: test
        });
    } catch (error) {
        console.error('Error adding patient test:', error);
        res.status(500).json({ success: false, message: 'Failed to add patient test' });
    }
});

// Update patient test status
router.put('/:labId/patient-tests/:testId', verifyToken, adminOnly, async (req, res) => {
    try {
        const lab = await Lab.findById(req.params.labId);

        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }

        const test = lab.patientTests.id(req.params.testId);

        if (!test) {
            return res.status(404).json({ success: false, message: 'Test not found' });
        }

        Object.assign(test, req.body);

        if (req.body.status === 'Completed') {
            test.resultDate = new Date();
        }

        lab.lastUpdatedBy = req.user.id;
        await lab.save();

        res.json({
            success: true,
            message: 'Test updated successfully',
            data: test
        });
    } catch (error) {
        console.error('Error updating patient test:', error);
        res.status(500).json({ success: false, message: 'Failed to update test' });
    }
});

// Get lab performance metrics
router.get('/:id/performance', verifyToken, adminOnly, async (req, res) => {
    try {
        const lab = await Lab.findById(req.params.id);

        if (!lab) {
            return res.status(404).json({ success: false, message: 'Lab not found' });
        }

        const now = new Date();
        const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, now.getDate());
        const lastYear = new Date(now.getFullYear() - 1, now.getMonth(), now.getDate());

        const lastMonthTests = lab.patientTests.filter(test =>
            new Date(test.requestDate) >= lastMonth
        );

        const lastYearTests = lab.patientTests.filter(test =>
            new Date(test.requestDate) >= lastYear
        );

        const completedTests = lab.patientTests.filter(test => test.status === 'Completed');
        const pendingTests = lab.patientTests.filter(test => test.status === 'Pending');
        const urgentTests = lab.patientTests.filter(test => test.urgency === 'Urgent');

        // Calculate average completion time
        const completionTimes = lab.patientTests
            .filter(test => test.status === 'Completed' && test.resultDate)
            .map(test => new Date(test.resultDate) - new Date(test.requestDate));

        const avgCompletionTime = completionTimes.length > 0
            ? completionTimes.reduce((a, b) => a + b, 0) / completionTimes.length
            : 0;

        res.json({
            success: true,
            data: {
                totalTests: lab.patientTests.length,
                completedTests: completedTests.length,
                pendingTests: pendingTests.length,
                urgentTests: urgentTests.length,
                lastMonthTests: lastMonthTests.length,
                lastYearTests: lastYearTests.length,
                averageCompletionTime: Math.round(avgCompletionTime / (1000 * 60 * 60 * 24)), // in days
                completionRate: lab.patientTests.length > 0
                    ? Math.round((completedTests.length / lab.patientTests.length) * 100)
                    : 0,
                urgentCompletionRate: urgentTests.length > 0
                    ? Math.round((urgentTests.filter(t => t.status === 'Completed').length / urgentTests.length) * 100)
                    : 0
            }
        });
    } catch (error) {
        console.error('Error fetching lab performance:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch performance data' });
    }
});

module.exports = router;
