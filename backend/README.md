# LabGo Backend

A healthcare application backend for lab test ordering and management.

## Features

- User authentication (patients, nurses, labs, admin)
- Lab management and test ordering
- Nurse applications and assignments
- Shop for medical products
- Multi-language support (English, Arabic, Kurdish)
- **Cloudflare R2 cloud storage for all uploads**

## Environment Variables

Create a `.env` file in the backend directory with the following:

```env
# Database Configuration
MONGODB_URI=mongodb://localhost:27017/labgo

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-change-in-production
JWT_EXPIRES_IN=24h

# Server Configuration
PORT=3000
NODE_ENV=development

# OTP Configuration
OTP_API_KEY=your-otp-api-key

# Cloudflare R2 Storage Configuration
R2_ACCOUNT_ID=your-account-id
R2_ACCESS_KEY_ID=your-access-key-id
R2_SECRET_ACCESS_KEY=your-secret-access-key
R2_BUCKET_NAME=labgo
R2_ENDPOINT=https://your-account-id.r2.cloudflarestorage.com
# R2_PUBLIC_URL=https://your-custom-domain.com (optional - for custom domain)
```

## Cloudflare R2 Storage

All file uploads are stored in Cloudflare R2 cloud storage:

- **Lab logos**: `/uploads/labs/`
- **Nurse applications**: `/uploads/nurse-applications/`
- **Prescriptions**: `/uploads/prescriptions/`
- **Test results**: `/uploads/results/`
- **Shop images**: `/uploads/shop/`
- **Test imports**: `/uploads/test-imports/`

### R2 Setup

1. Create a Cloudflare R2 bucket named `labgo`
2. Create an API token with R2 read/write permissions
3. Add credentials to `.env` file

### Migration Script

To migrate existing local files to R2:

```bash
node scripts/migrate-to-r2.js
```

## Installation

```bash
npm install
```

## Running

Development:
```bash
npm run dev
```

Production:
```bash
npm start
```

## API Documentation

See the routes folder for API endpoints:

- `/api/auth` - Authentication
- `/api/orders` - Order management
- `/api/shop` - Shop products
- `/api/admin/*` - Admin endpoints
- `/api/nurse/*` - Nurse endpoints
- `/api/lab/*` - Lab endpoints
