/**
 * Migration Script: Local Uploads to Cloudflare R2
 * 
 * This script migrates existing local upload files to R2 storage.
 * Run this script once to transfer all existing files.
 * 
 * Usage: node scripts/migrate-to-r2.js
 */

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const r2Service = require('../services/r2Service');
const r2Config = require('../config/r2');

// Directories to migrate
const uploadDirs = [
    { local: 'uploads/labs', r2Type: 'labs' },
    { local: 'uploads/nurse-applications', r2Type: 'nurseApplications' },
    { local: 'uploads/prescriptions', r2Type: 'prescriptions' },
    { local: 'uploads/results', r2Type: 'results' },
    { local: 'uploads/shop', r2Type: 'shop' },
    { local: 'uploads/test-imports', r2Type: 'testImports' }
];

async function migrateDirectory(localDir, r2Type) {
    const fullPath = path.join(__dirname, '..', localDir);
    
    if (!fs.existsSync(fullPath)) {
        console.log(`Directory not found: ${localDir} - Skipping`);
        return { migrated: 0, failed: 0, skipped: 0 };
    }

    const files = fs.readdirSync(fullPath);
    const stats = { migrated: 0, failed: 0, skipped: 0 };

    console.log(`\nMigrating ${localDir} (${files.length} files)...`);

    for (const file of files) {
        const filePath = path.join(fullPath, file);
        
        // Skip directories
        if (fs.statSync(filePath).isDirectory()) {
            console.log(`  Skipping directory: ${file}`);
            stats.skipped++;
            continue;
        }

        // Skip hidden files
        if (file.startsWith('.')) {
            stats.skipped++;
            continue;
        }

        try {
            const result = await r2Service.migrateLocalFile(filePath, r2Type);
            
            if (result.success) {
                console.log(`  ✓ Migrated: ${file} -> ${result.url}`);
                stats.migrated++;
            } else {
                console.log(`  ✗ Failed: ${file} - ${result.error}`);
                stats.failed++;
            }
        } catch (error) {
            console.log(`  ✗ Error: ${file} - ${error.message}`);
            stats.failed++;
        }
    }

    return stats;
}

async function updateDatabaseUrls() {
    /**
     * This function updates URLs in the database from local paths to R2 paths.
     * Since R2 paths have the same structure (/uploads/...), the URLs in the database
     * should work without modification. However, if you need to update to full R2 URLs,
     * uncomment and modify the code below.
     */
    
    console.log('\n--- Database URL Update ---');
    console.log('Database URLs use the same path format (/uploads/...) which is proxied to R2.');
    console.log('No database changes required.');
    
    // If you want to update to full R2 URLs in the future:
    // const mongoose = require('mongoose');
    // const Lab = require('../models/Lab');
    // const Product = require('../models/Product');
    // const Category = require('../models/Category');
    // const Order = require('../models/Order');
    // const NurseApplication = require('../models/NurseApplication');
    // 
    // await mongoose.connect(process.env.MONGODB_URI);
    // 
    // // Update Lab logos
    // const labs = await Lab.find({ logo: { $regex: '^/uploads/' } });
    // for (const lab of labs) {
    //     lab.logo = r2Service.getPublicUrl(lab.logo);
    //     await lab.save();
    // }
    // // ... repeat for other models
}

async function main() {
    console.log('='.repeat(60));
    console.log('LabGo Local to R2 Migration Script');
    console.log('='.repeat(60));
    console.log(`\nR2 Bucket: ${r2Config.bucketName}`);
    console.log(`R2 Endpoint: ${r2Config.endpoint}\n`);

    const totalStats = { migrated: 0, failed: 0, skipped: 0 };

    for (const dir of uploadDirs) {
        const stats = await migrateDirectory(dir.local, dir.r2Type);
        totalStats.migrated += stats.migrated;
        totalStats.failed += stats.failed;
        totalStats.skipped += stats.skipped;
    }

    console.log('\n' + '='.repeat(60));
    console.log('Migration Summary');
    console.log('='.repeat(60));
    console.log(`✓ Migrated: ${totalStats.migrated} files`);
    console.log(`✗ Failed: ${totalStats.failed} files`);
    console.log(`→ Skipped: ${totalStats.skipped} items`);

    // Update database URLs if needed
    await updateDatabaseUrls();

    console.log('\n' + '='.repeat(60));
    console.log('Migration Complete!');
    console.log('='.repeat(60));
    console.log('\nNext steps:');
    console.log('1. Test the application to ensure files are served correctly');
    console.log('2. Once verified, you can safely delete local upload directories');
    console.log('3. The local files were preserved during migration for safety');
}

main().catch(err => {
    console.error('Migration failed:', err);
    process.exit(1);
});
