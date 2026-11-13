/**
 * Cloudflare R2 Configuration
 * 
 * R2 bucket structure: labgo/uploads/
 *   - /labs          (lab logos)
 *   - /lab-documents (private lab registration documents)
 *   - /nurse-applications (nurse application documents)
 *   - /prescriptions (prescription images)
 *   - /profile-pictures (user profile pictures)
 *   - /results       (test result files)
 *   - /shop          (product/category images)
 *   - /test-imports  (test import Excel/CSV files)
 *   - /tests         (optional custom images for lab tests)
 */

const r2Config = {
    accountId: process.env.R2_ACCOUNT_ID || '',
    accessKeyId: process.env.R2_ACCESS_KEY_ID || '',
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY || '',
    bucketName: process.env.R2_BUCKET_NAME || 'labgo',
    
    // S3-compatible endpoint
    endpoint: process.env.R2_ENDPOINT || (process.env.R2_ACCOUNT_ID ? `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com` : ''),
    
    // Public URL for serving files (configure this in R2 dashboard if using custom domain)
    // If using R2 public bucket or custom domain, set this
    publicUrl: process.env.R2_PUBLIC_URL || null,
    
    // Upload paths mapping
    paths: {
        labs: 'uploads/labs',
        labDocuments: 'uploads/lab-documents',
        nurseApplications: 'uploads/nurse-applications',
        prescriptions: 'uploads/prescriptions',
        profilePictures: 'uploads/profile-pictures',
        medicineQuotes: 'uploads/medicine-quotes',
        results: 'uploads/results',
        shop: 'uploads/shop',
        testImports: 'uploads/test-imports',
        serviceIcons: 'uploads/service-icons',
        tests: 'uploads/tests',
        banners: 'uploads/banners',
        market: 'uploads/market',
        support: 'uploads/support'
    },

    // Region (R2 uses 'auto' for automatic region selection)
    region: 'auto'
};

module.exports = r2Config;
