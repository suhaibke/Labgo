/**
 * R2 Upload Middleware
 * 
 * Custom multer middleware that uploads files to R2 instead of local storage.
 * Provides drop-in replacement for existing multer configurations.
 */

const multer = require('multer');
const path = require('path');
const r2Service = require('../services/r2Service');

// Use memory storage - files are stored in buffer and uploaded to R2
const memoryStorage = multer.memoryStorage();

/**
 * File filter for images
 */
const imageFilter = (req, file, cb) => {
    const isImage = file.mimetype.startsWith('image/');
    const extname = path.extname(file.originalname).toLowerCase();
    const allowedImageExtensions = /\.(jpeg|jpg|png|gif|heic|heif|webp)$/i;
    
    if (isImage || allowedImageExtensions.test(extname)) {
        cb(null, true);
    } else {
        cb(new Error('Only image files are allowed'), false);
    }
};

/**
 * File filter for images and PDFs (documents)
 */
const documentFilter = (req, file, cb) => {
    const isImage = file.mimetype.startsWith('image/');
    const isPdf = file.mimetype === 'application/pdf';
    const extname = path.extname(file.originalname).toLowerCase();
    const allowedExtensions = /\.(jpeg|jpg|png|gif|heic|heif|webp|pdf)$/i;
    
    if (isImage || isPdf || allowedExtensions.test(extname)) {
        cb(null, true);
    } else {
        cb(new Error('Only image and PDF files are allowed'), false);
    }
};

/**
 * Registration uploads mix a public logo with private identity/licensing files.
 * Document extensions must agree with their MIME type to avoid obvious spoofing.
 */
const labRegistrationFileFilter = (req, file, cb) => {
    if (file.fieldname === 'logo') {
        return imageFilter(req, file, cb);
    }

    const extension = path.extname(file.originalname).toLowerCase();
    const allowedDocumentTypes = {
        '.pdf': ['application/pdf'],
        '.jpg': ['image/jpeg'],
        '.jpeg': ['image/jpeg'],
        '.png': ['image/png'],
        '.webp': ['image/webp'],
        '.heic': ['image/heic', 'image/heif'],
        '.heif': ['image/heic', 'image/heif']
    };

    if (allowedDocumentTypes[extension]?.includes(file.mimetype)) {
        return cb(null, true);
    }

    return cb(new Error('Lab documents must be valid image or PDF files'), false);
};

/**
 * File filter for Excel and CSV files
 */
const spreadsheetFilter = (req, file, cb) => {
    const allowedTypes = [
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/csv'
    ];
    const extname = ['.xls', '.xlsx', '.csv'].includes(
        path.extname(file.originalname).toLowerCase()
    );
    
    if (allowedTypes.includes(file.mimetype) || extname) {
        cb(null, true);
    } else {
        cb(new Error('Only Excel (.xls, .xlsx) and CSV files are allowed'), false);
    }
};

/**
 * Create multer instance for lab logo uploads
 */
const labLogoUpload = multer({
    storage: memoryStorage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
    fileFilter: imageFilter
});

/**
 * Create multer instance for user profile picture uploads
 */
const profilePictureUpload = multer({
    storage: memoryStorage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
    fileFilter: imageFilter
});

/**
 * Create multer instance for home page banner uploads
 */
const bannerUpload = multer({
    storage: memoryStorage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
    fileFilter: imageFilter
});

/**
 * Create multer instance for admin medicine-quote photo uploads
 */
const medicineQuoteUpload = multer({
    storage: memoryStorage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
    fileFilter: imageFilter
});

/**
 * Create multer instance for quick-service icon uploads.
 * Capped tighter than other images (200KB) since these render at small
 * sizes throughout the app and are fetched on every home page load.
 */
const serviceIconUpload = multer({
    storage: memoryStorage,
    limits: { fileSize: 200 * 1024 }, // 200KB
    fileFilter: imageFilter
});

const labRegistrationUpload = multer({
    storage: memoryStorage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB per file
    fileFilter: labRegistrationFileFilter
});

/**
 * Create multer instance for shop image uploads
 */
const shopImageUpload = multer({
    storage: memoryStorage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
    fileFilter: imageFilter
});

/**
 * Create multer instance for prescription uploads
 */
const prescriptionUpload = multer({
    storage: memoryStorage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
    fileFilter: documentFilter
});

/**
 * Create multer instance for nurse application documents
 */
const nurseApplicationUpload = multer({
    storage: memoryStorage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
    fileFilter: documentFilter
});

/**
 * Create multer instance for test result uploads
 */
const testResultUpload = multer({
    storage: memoryStorage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
    fileFilter: documentFilter
});

/**
 * Create multer instance for test import uploads (Excel/CSV)
 */
const testImportUpload = multer({
    storage: memoryStorage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
    fileFilter: spreadsheetFilter
});

/**
 * Middleware to process uploaded file and upload to R2
 * This is called AFTER multer processes the file
 * 
 * @param {string} uploadType - Type of upload (matches r2Config.paths keys)
 * @param {string} prefix - Filename prefix
 */
function processR2Upload(uploadType, prefix = '') {
    return async (req, res, next) => {
        try {
            // Handle single file upload (req.file)
            if (req.file) {
                const result = await r2Service.uploadFromMulter(req.file, uploadType, prefix);
                // Store R2 result on the file object for route handler access
                req.file.r2 = result;
                req.file.r2Url = result.url;
            }

            // Handle multiple file uploads (req.files)
            if (req.files) {
                // req.files can be an array or an object (for fields())
                if (Array.isArray(req.files)) {
                    for (let i = 0; i < req.files.length; i++) {
                        const result = await r2Service.uploadFromMulter(req.files[i], uploadType, prefix);
                        req.files[i].r2 = result;
                        req.files[i].r2Url = result.url;
                    }
                } else {
                    // Object with field names as keys
                    for (const fieldName of Object.keys(req.files)) {
                        for (let i = 0; i < req.files[fieldName].length; i++) {
                            const result = await r2Service.uploadFromMulter(
                                req.files[fieldName][i], 
                                uploadType, 
                                prefix
                            );
                            req.files[fieldName][i].r2 = result;
                            req.files[fieldName][i].r2Url = result.url;
                        }
                    }
                }
            }

            next();
        } catch (error) {
            console.error('R2 upload middleware error:', error);
            return res.status(500).json({
                success: false,
                message: 'File upload failed',
                error: error.message
            });
        }
    };
}

/**
 * Upload a lab logo to the public logo prefix and all registration documents
 * to the private document prefix. Any partial upload is rolled back.
 */
function processLabRegistrationUploads() {
    return async (req, res, next) => {
        const uploadedUrls = [];

        try {
            for (const [fieldName, files] of Object.entries(req.files || {})) {
                const isLogo = fieldName === 'logo';

                for (const file of files) {
                    const result = await r2Service.uploadFromMulter(
                        file,
                        isLogo ? 'labs' : 'labDocuments',
                        isLogo ? 'lab-logo-' : 'lab-document-'
                    );
                    file.r2 = result;
                    file.r2Url = result.url;
                    uploadedUrls.push(result.url);
                }
            }

            next();
        } catch (error) {
            await Promise.all(uploadedUrls.map(url => r2Service.deleteFile(url)));
            console.error('R2 lab registration upload error:', error);
            return res.status(500).json({
                success: false,
                message: 'File upload failed',
                error: error.message
            });
        }
    };
}

/**
 * Combined middleware factory - multer + R2 upload in one
 * 
 * @param {string} uploadType - Type of upload
 * @param {string} fieldName - Form field name
 * @param {string} prefix - Filename prefix
 * @param {Object} options - Additional options
 */
function r2SingleUpload(uploadType, fieldName, prefix = '', options = {}) {
    let multerInstance;
    
    switch (uploadType) {
        case 'labs':
            multerInstance = labLogoUpload;
            break;
        case 'shop':
            multerInstance = shopImageUpload;
            break;
        case 'prescriptions':
            multerInstance = prescriptionUpload;
            break;
        case 'profilePictures':
            multerInstance = profilePictureUpload;
            break;
        case 'banners':
            multerInstance = bannerUpload;
            break;
        case 'medicineQuotes':
            multerInstance = medicineQuoteUpload;
            break;
        case 'nurseApplications':
            multerInstance = nurseApplicationUpload;
            break;
        case 'results':
            multerInstance = testResultUpload;
            break;
        case 'testImports':
            multerInstance = testImportUpload;
            break;
        case 'serviceIcons':
            multerInstance = serviceIconUpload;
            break;
        case 'tests':
            multerInstance = serviceIconUpload;
            break;
        default:
            multerInstance = multer({ storage: memoryStorage, limits: { fileSize: 5 * 1024 * 1024 } });
    }

    return [
        multerInstance.single(fieldName),
        processR2Upload(uploadType, prefix)
    ];
}

/**
 * Combined middleware factory for multiple files - multer + R2 upload
 */
function r2ArrayUpload(uploadType, fieldName, maxCount, prefix = '') {
    let multerInstance;
    
    switch (uploadType) {
        case 'shop':
            multerInstance = shopImageUpload;
            break;
        default:
            multerInstance = multer({ storage: memoryStorage, limits: { fileSize: 5 * 1024 * 1024 } });
    }

    return [
        multerInstance.array(fieldName, maxCount),
        processR2Upload(uploadType, prefix)
    ];
}

/**
 * Combined middleware factory for multiple fields - multer + R2 upload
 */
function r2FieldsUpload(uploadType, fields, prefix = '') {
    let multerInstance;
    
    switch (uploadType) {
        case 'nurseApplications':
            multerInstance = nurseApplicationUpload;
            break;
        default:
            multerInstance = multer({ storage: memoryStorage, limits: { fileSize: 5 * 1024 * 1024 } });
    }

    return [
        multerInstance.fields(fields),
        processR2Upload(uploadType, prefix)
    ];
}

function r2LabRegistrationUpload(fields) {
    return [
        labRegistrationUpload.fields(fields),
        processLabRegistrationUploads()
    ];
}

module.exports = {
    // Multer instances (for custom usage)
    labLogoUpload,
    labRegistrationUpload,
    shopImageUpload,
    prescriptionUpload,
    profilePictureUpload,
    medicineQuoteUpload,
    nurseApplicationUpload,
    testResultUpload,
    testImportUpload,
    serviceIconUpload,

    // Processing middleware
    processR2Upload,
    
    // Combined middleware factories
    r2SingleUpload,
    r2ArrayUpload,
    r2FieldsUpload,
    r2LabRegistrationUpload,
    
    // File filters (for custom multer configurations)
    imageFilter,
    documentFilter,
    labRegistrationFileFilter,
    spreadsheetFilter
};
