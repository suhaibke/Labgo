// A lab signs itself up from the lab app:
//   1. POST /api/auth/send-otp  { phone, purpose: 'register' }  → SMS code
//   2. POST /api/auth/lab-register (multipart) with the code and documents
// The owner account and the lab are created, the lab "Pending" until the LabGo
// admin reviews the documents and activates it from the admin panel.
const express = require('express');
const bcrypt = require('bcryptjs');
const User = require('../../models/User');
const Lab = require('../../models/Lab');
const otpService = require('../../services/otpService');
const r2Service = require('../../services/r2Service');
const { r2LabRegistrationUpload } = require('../../middleware/r2Upload');
const { buildLabDocuments, getUploadedFileUrls } = require('../../helpers/lab-documents');
const { getPhoneLoginCandidates, findByPhone } = require('../../helpers/phone');

const router = express.Router();
// Opening licence (one file) and the owner's ID card (front and back).
const upload = r2LabRegistrationUpload([
    { name: 'labOpeningLicense', maxCount: 1 },
    { name: 'ownerUnifiedCard', maxCount: 2 },
]);

const clip = (v, n) => String(v ?? '').trim().slice(0, n);

router.post('/lab-register', ...upload, async (req, res) => {
    const fail = async (status, message, code) => {
        await Promise.all(getUploadedFileUrls(req.files).map((u) => r2Service.deleteFile(u).catch(() => {})));
        return res.status(status).json({ success: false, message, code });
    };
    try {
        const b = req.body || {};
        const ownerName = clip(b.ownerName, 120);
        const labName = clip(b.labName, 160);
        const phone = clip(b.phone, 30);
        const email = clip(b.email, 160).toLowerCase();
        const password = String(b.password || '');
        const city = clip(b.city, 60);
        if (!ownerName || !labName) return fail(400, 'Owner and lab names are required', 'name');
        if (phone.replace(/\D/g, '').length < 10) return fail(400, 'Enter a valid phone number', 'phone');
        if (!/^\S+@\S+\.\S+$/.test(email)) return fail(400, 'Enter a valid email', 'email');
        if (password.length < 8) return fail(400, 'Password must be at least 8 characters', 'password');
        if (!city) return fail(400, 'City is required', 'city');
        if (!req.files?.labOpeningLicense?.length) return fail(400, 'Upload the lab opening licence', 'documents');

        // The SMS code sent to this phone (kept by otpService for new numbers).
        const check = otpService.verifyOtpLocal({ phone, code: clip(b.code, 6) });
        if (!check.success) return fail(400, check.message || 'Invalid OTP code', 'otp');

        if (await findByPhone(User, getPhoneLoginCandidates(phone))) return fail(409, 'This phone number already has an account', 'phoneTaken');
        if (await User.exists({ email })) return fail(409, 'This email already has an account', 'emailTaken');
        if (await findByPhone(Lab, getPhoneLoginCandidates(phone))) return fail(409, 'A lab with this phone already exists', 'phoneTaken');

        const user = await User.create({
            name: ownerName, email, phone, role: 'lab',
            password: await bcrypt.hash(password, await bcrypt.genSalt(12)),
            phoneVerified: true,
        });
        try {
            const lab = await Lab.create({
                name: labName, email, phone, city, address: clip(b.address, 300),
                licenseNumber: clip(b.licenseNumber, 80) || undefined,
                ownerId: user._id, createdBy: user._id, lastUpdatedBy: user._id,
                status: 'Pending',
                documents: buildLabDocuments(req.files),
            });
            console.log(`Lab registration: ${lab.name} (L${lab.labNo}) waiting for review`);
            return res.status(201).json({ success: true, data: { status: 'Pending', labNo: lab.labNo ? `L${lab.labNo}` : '' } });
        } catch (error) {
            await User.deleteOne({ _id: user._id }).catch(() => {});
            throw error;
        }
    } catch (error) {
        console.error('Lab registration error:', error);
        return fail(500, 'Error creating the lab account', 'server');
    }
});

module.exports = router;
