/**
 * Cloudflare R2 Storage Service
 * 
 * Handles file uploads, downloads, and deletion for R2 bucket storage.
 * Uses AWS SDK v3 for S3-compatible operations.
 */

const { 
    S3Client, 
    PutObjectCommand, 
    GetObjectCommand, 
    DeleteObjectCommand,
    HeadObjectCommand 
} = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const fs = require('fs');
const path = require('path');
const r2Config = require('../config/r2');

// Initialize S3 client for R2
const s3Client = new S3Client({
    region: r2Config.region,
    endpoint: r2Config.endpoint,
    credentials: {
        accessKeyId: r2Config.accessKeyId,
        secretAccessKey: r2Config.secretAccessKey
    },
    // Required for R2 compatibility
    forcePathStyle: true
});

/**
 * Get the content type based on file extension
 */
function getContentType(filename) {
    const ext = path.extname(filename).toLowerCase();
    const mimeTypes = {
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.gif': 'image/gif',
        '.webp': 'image/webp',
        '.heic': 'image/heic',
        '.heif': 'image/heif',
        '.pdf': 'application/pdf',
        '.xls': 'application/vnd.ms-excel',
        '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        '.csv': 'text/csv'
    };
    return mimeTypes[ext] || 'application/octet-stream';
}

/**
 * Generate a unique filename with timestamp
 */
function generateUniqueFilename(originalFilename, prefix = '') {
    const uniqueSuffix = Date.now() + '-' + Math.random().toString(36).substring(2, 15);
    const ext = path.extname(originalFilename);
    return `${prefix}${uniqueSuffix}${ext}`;
}

/**
 * Upload a file to R2 from a local file path
 * 
 * @param {string} localFilePath - Path to the local file
 * @param {string} uploadPath - R2 path (e.g., 'uploads/labs')
 * @param {string} filename - Desired filename in R2
 * @param {Object} options - Additional options
 * @returns {Promise<Object>} - Upload result with URL
 */
async function uploadFile(localFilePath, uploadPath, filename, options = {}) {
    try {
        const fileContent = fs.readFileSync(localFilePath);
        const key = `${uploadPath}/${filename}`;
        const contentType = options.contentType || getContentType(filename);

        const command = new PutObjectCommand({
            Bucket: r2Config.bucketName,
            Key: key,
            Body: fileContent,
            ContentType: contentType,
            // Make file publicly readable if bucket allows
            // ACL: 'public-read', // Note: R2 doesn't support ACLs, use bucket policies instead
            Metadata: options.metadata || {}
        });

        await s3Client.send(command);

        // Delete local file after successful upload (optional)
        if (options.deleteLocal !== false) {
            try {
                fs.unlinkSync(localFilePath);
            } catch (unlinkError) {
                console.warn('Could not delete local file:', unlinkError.message);
            }
        }

        // Return the R2 path (for storing in database)
        const r2Url = `/${key}`;
        
        return {
            success: true,
            key: key,
            url: r2Url,
            bucket: r2Config.bucketName,
            contentType: contentType
        };
    } catch (error) {
        console.error('R2 upload error:', error);
        throw new Error(`Failed to upload file to R2: ${error.message}`);
    }
}

/**
 * Upload a file to R2 from a buffer
 * 
 * @param {Buffer} buffer - File buffer
 * @param {string} uploadPath - R2 path (e.g., 'uploads/labs')
 * @param {string} filename - Desired filename in R2
 * @param {Object} options - Additional options
 * @returns {Promise<Object>} - Upload result with URL
 */
async function uploadBuffer(buffer, uploadPath, filename, options = {}) {
    try {
        const key = `${uploadPath}/${filename}`;
        const contentType = options.contentType || getContentType(filename);

        const command = new PutObjectCommand({
            Bucket: r2Config.bucketName,
            Key: key,
            Body: buffer,
            ContentType: contentType,
            Metadata: options.metadata || {}
        });

        await s3Client.send(command);

        // Return the R2 path (for storing in database)
        const r2Url = `/${key}`;
        
        return {
            success: true,
            key: key,
            url: r2Url,
            bucket: r2Config.bucketName,
            contentType: contentType
        };
    } catch (error) {
        console.error('R2 upload error:', error);
        throw new Error(`Failed to upload buffer to R2: ${error.message}`);
    }
}

/**
 * Upload from multer file object
 * This is the main function used by route handlers
 * 
 * @param {Object} multerFile - Multer file object (from req.file)
 * @param {string} uploadType - Type of upload ('labs', 'shop', 'prescriptions', etc.)
 * @param {string} prefix - Filename prefix (e.g., 'lab-logo-', 'product-')
 * @returns {Promise<Object>} - Upload result with URL
 */
async function uploadFromMulter(multerFile, uploadType, prefix = '') {
    if (!multerFile) {
        throw new Error('No file provided');
    }

    const uploadPath = r2Config.paths[uploadType];
    if (!uploadPath) {
        throw new Error(`Invalid upload type: ${uploadType}`);
    }

    const filename = generateUniqueFilename(multerFile.originalname, prefix);

    // If multer stored file locally (diskStorage), upload from path
    if (multerFile.path) {
        return await uploadFile(multerFile.path, uploadPath, filename, {
            contentType: multerFile.mimetype,
            deleteLocal: true
        });
    }
    
    // If multer stored file in memory (memoryStorage), upload from buffer
    if (multerFile.buffer) {
        return await uploadBuffer(multerFile.buffer, uploadPath, filename, {
            contentType: multerFile.mimetype
        });
    }

    throw new Error('Invalid multer file object');
}

/**
 * Delete a file from R2
 * 
 * @param {string} fileUrl - The URL/key of the file (e.g., '/uploads/labs/file.jpg' or 'uploads/labs/file.jpg')
 * @returns {Promise<boolean>} - Success status
 */
async function deleteFile(fileUrl) {
    try {
        if (!fileUrl) return true;

        // Remove leading slash if present
        let key = fileUrl.startsWith('/') ? fileUrl.substring(1) : fileUrl;
        
        // Handle full URLs
        if (key.startsWith('http')) {
            const url = new URL(key);
            key = url.pathname.substring(1);
        }

        const command = new DeleteObjectCommand({
            Bucket: r2Config.bucketName,
            Key: key
        });

        await s3Client.send(command);
        return true;
    } catch (error) {
        console.error('R2 delete error:', error);
        // Don't throw - file might not exist, which is OK
        return false;
    }
}

/**
 * Check if a file exists in R2
 * 
 * @param {string} fileUrl - The URL/key of the file
 * @returns {Promise<boolean>} - Whether file exists
 */
async function fileExists(fileUrl) {
    try {
        if (!fileUrl) return false;

        let key = fileUrl.startsWith('/') ? fileUrl.substring(1) : fileUrl;

        const command = new HeadObjectCommand({
            Bucket: r2Config.bucketName,
            Key: key
        });

        await s3Client.send(command);
        return true;
    } catch (error) {
        if (error.name === 'NotFound') {
            return false;
        }
        console.error('R2 head object error:', error);
        return false;
    }
}

/**
 * Get a signed URL for temporary access to a private file
 * 
 * @param {string} fileUrl - The URL/key of the file
 * @param {number} expiresIn - URL expiration time in seconds (default: 1 hour)
 * @returns {Promise<string>} - Signed URL
 */
async function getSignedDownloadUrl(fileUrl, expiresIn = 3600) {
    try {
        if (!fileUrl) return null;

        let key = fileUrl.startsWith('/') ? fileUrl.substring(1) : fileUrl;

        const command = new GetObjectCommand({
            Bucket: r2Config.bucketName,
            Key: key
        });

        const signedUrl = await getSignedUrl(s3Client, command, { expiresIn });
        return signedUrl;
    } catch (error) {
        console.error('R2 get signed URL error:', error);
        throw new Error(`Failed to get signed URL: ${error.message}`);
    }
}

/**
 * Get file as a stream (for proxying downloads)
 * 
 * @param {string} fileUrl - The URL/key of the file
 * @returns {Promise<Object>} - Object containing stream and metadata
 */
async function getFileStream(fileUrl) {
    try {
        if (!fileUrl) return null;

        let key = fileUrl.startsWith('/') ? fileUrl.substring(1) : fileUrl;

        const command = new GetObjectCommand({
            Bucket: r2Config.bucketName,
            Key: key
        });

        const response = await s3Client.send(command);
        
        return {
            stream: response.Body,
            contentType: response.ContentType,
            contentLength: response.ContentLength,
            metadata: response.Metadata
        };
    } catch (error) {
        console.error('R2 get stream error:', error);
        throw new Error(`Failed to get file stream: ${error.message}`);
    }
}

/**
 * Get the public URL for a file
 * If R2_PUBLIC_URL is configured, returns public URL
 * Otherwise, returns a path that should be handled by the proxy endpoint
 * 
 * @param {string} storedUrl - The stored URL/key (e.g., '/uploads/labs/file.jpg')
 * @returns {string} - Full URL or path for accessing the file
 */
function getPublicUrl(storedUrl) {
    if (!storedUrl) return null;
    
    // If it's already a full URL, return as is
    if (storedUrl.startsWith('http')) {
        return storedUrl;
    }

    // If public URL is configured, use it
    if (r2Config.publicUrl) {
        const key = storedUrl.startsWith('/') ? storedUrl.substring(1) : storedUrl;
        return `${r2Config.publicUrl}/${key}`;
    }

    // Otherwise, return the path as-is (will be served by proxy endpoint)
    return storedUrl;
}

/**
 * Migrate a local file to R2 (useful for batch migration)
 * 
 * @param {string} localPath - Local file path
 * @param {string} uploadType - Type of upload
 * @returns {Promise<Object>} - Upload result
 */
async function migrateLocalFile(localPath, uploadType) {
    try {
        if (!fs.existsSync(localPath)) {
            return { success: false, error: 'Local file not found' };
        }

        const uploadPath = r2Config.paths[uploadType];
        if (!uploadPath) {
            throw new Error(`Invalid upload type: ${uploadType}`);
        }

        const filename = path.basename(localPath);
        
        return await uploadFile(localPath, uploadPath, filename, {
            deleteLocal: false // Keep local file during migration
        });
    } catch (error) {
        console.error('Migration error:', error);
        return { success: false, error: error.message };
    }
}

module.exports = {
    uploadFile,
    uploadBuffer,
    uploadFromMulter,
    deleteFile,
    fileExists,
    getSignedDownloadUrl,
    getFileStream,
    getPublicUrl,
    migrateLocalFile,
    generateUniqueFilename,
    getContentType,
    s3Client,
    r2Config
};
