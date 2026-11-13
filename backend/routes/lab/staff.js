// Users & roles: the lab owner (or a staff member with the 'users'
// permission) manages staff accounts and what each role may do.
const express = require('express');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const User = require('../../models/User');
const Lab = require('../../models/Lab');
const { PERMISSIONS, DEFAULT_ROLES, labRoles } = require('../../helpers/lab-permissions');
const { getPhoneLoginCandidates, findByPhone } = require('../../helpers/phone');

const router = express.Router();
const COLORS = ['#FF5A00', '#007AFF', '#34C759', '#AF52DE', '#FF3B30', '#00C7BE', '#FF9500', '#8E8E93'];

function langOf(req) {
    const currentLang = req.cookies?.lang
        || req.headers['accept-language']?.split(',')[0]?.split('-')[0]
        || 'ar';
    return {
        currentLang,
        direction: ['ar', 'ku'].includes(currentLang) ? 'rtl' : 'ltr',
        font: currentLang === 'ar' ? 'Cairo, sans-serif' : 'Inter, sans-serif',
    };
}

function publicStaff(u) {
    return {
        _id: u._id, name: u.name, phone: u.phone || '', email: u.email || '',
        roleKey: u.labStaff?.roleKey || '', active: u.labStaff?.active !== false, addedAt: u.labStaff?.addedAt || null,
    };
}

async function staffOf(lab) {
    const list = await User.find({ 'labStaff.labId': lab._id, role: 'lab' }).select('-password').sort({ 'labStaff.addedAt': -1 }).lean();
    return list.map(publicStaff);
}

function fail(res, status, message, code) {
    return res.status(status).json({ success: false, message, code });
}

router.get('/users', async (req, res) => {
    try {
        res.render('dashboard/lab-users', {
            lab: req.lab,
            user: req.user,
            title: req.lab.name,
            ...langOf(req),
            activeSection: 'users',
            dataJson: JSON.stringify({
                staff: await staffOf(req.lab),
                roles: labRoles(req.lab),
                permissions: PERMISSIONS,
                owner: { name: req.isLabOwner ? req.user.name : '', isMe: req.isLabOwner },
            }).replace(/</g, '\\u003c'),
        });
    } catch (error) {
        console.error('Users page error:', error);
        res.status(500).render('error', { message: 'Error loading users', error: null });
    }
});

router.get('/api/staff', async (req, res) => {
    try {
        res.json({ success: true, data: { staff: await staffOf(req.lab), roles: labRoles(req.lab) } });
    } catch (error) {
        console.error('List staff error:', error);
        fail(res, 500, 'Error loading staff');
    }
});

router.post('/api/staff', async (req, res) => {
    try {
        const { name, phone, email, password, roleKey } = req.body || {};
        if (!String(name || '').trim()) return fail(res, 400, 'Name is required', 'name');
        if (String(password || '').length < 6) return fail(res, 400, 'Password must be at least 6 characters', 'password');
        if (!labRoles(req.lab).some((r) => r.key === roleKey)) return fail(res, 400, 'Choose a role', 'role');
        const digits = String(phone || '').replace(/\D/g, '');
        if (digits.length < 10) return fail(res, 400, 'A valid phone number is required', 'phone');

        const candidates = getPhoneLoginCandidates(String(phone));
        if (await findByPhone(User, candidates)) return fail(res, 409, 'This phone number already has an account', 'phoneTaken');
        const cleanEmail = String(email || '').trim().toLowerCase();
        if (cleanEmail && await User.findOne({ email: cleanEmail })) return fail(res, 409, 'This email already has an account', 'emailTaken');

        const user = new User({
            name: String(name).trim().slice(0, 120),
            phone: candidates.find((c) => /^0\d{10}$/.test(c)) || digits,
            email: cleanEmail || undefined,
            password: await bcrypt.hash(String(password), 12),
            role: 'lab',
            labStaff: { labId: req.lab._id, roleKey, active: true, addedBy: req.user._id, addedAt: new Date() },
        });
        await user.save();
        res.status(201).json({ success: true, data: publicStaff(user) });
    } catch (error) {
        console.error('Create staff error:', error);
        fail(res, 500, 'Error creating the account');
    }
});

// Save the whole roles list (built-in overrides + custom roles).
router.put('/api/staff/roles', async (req, res) => {
    try {
        const incoming = Array.isArray(req.body?.roles) ? req.body.roles.slice(0, 30) : null;
        if (!incoming) return fail(res, 400, 'Roles are required');
        const builtInKeys = DEFAULT_ROLES.map((r) => r.key);
        const seen = new Set();
        const roles = [];
        for (const r of incoming) {
            const isBuiltIn = builtInKeys.includes(r.key);
            const key = isBuiltIn ? r.key : (/^c-[a-z0-9]{6,12}$/.test(r.key || '') ? r.key : `c-${crypto.randomBytes(4).toString('hex')}`);
            if (seen.has(key)) continue;
            seen.add(key);
            const name = String(r.name || '').trim().slice(0, 60);
            if (!isBuiltIn && !name) continue;
            roles.push({
                key,
                name,
                color: COLORS.includes(r.color) ? r.color : (isBuiltIn ? '' : COLORS[roles.length % COLORS.length]),
                permissions: key === 'admin' ? [...PERMISSIONS] : (Array.isArray(r.permissions) ? r.permissions.filter((p) => PERMISSIONS.includes(p)) : []),
            });
        }
        // A custom role still used by someone cannot disappear.
        const removed = labRoles(req.lab).filter((r) => !r.isDefault && !seen.has(r.key)).map((r) => r.key);
        if (removed.length && await User.exists({ 'labStaff.labId': req.lab._id, 'labStaff.roleKey': { $in: removed } })) {
            return fail(res, 400, 'Move the staff using this role to another role first', 'roleInUse');
        }
        const lab = await Lab.findById(req.lab._id);
        lab.staffRoles = roles;
        await lab.save();
        res.json({ success: true, data: { roles: labRoles(lab) } });
    } catch (error) {
        console.error('Save roles error:', error);
        fail(res, 500, 'Error saving roles');
    }
});

async function loadStaff(req, res) {
    const user = await User.findOne({ _id: req.params.id, 'labStaff.labId': req.lab._id, role: 'lab' });
    if (!user) {
        fail(res, 404, 'Staff member not found');
        return null;
    }
    return user;
}

router.put('/api/staff/:id', async (req, res) => {
    try {
        const user = await loadStaff(req, res);
        if (!user) return;
        const { name, roleKey, active, password } = req.body || {};
        if (String(user._id) === String(req.user._id) && (active === false || (roleKey && roleKey !== user.labStaff.roleKey))) {
            return fail(res, 400, 'You cannot change your own role or disable yourself', 'self');
        }
        if (typeof name === 'string' && name.trim()) user.name = name.trim().slice(0, 120);
        if (roleKey !== undefined) {
            if (!labRoles(req.lab).some((r) => r.key === roleKey)) return fail(res, 400, 'Choose a role', 'role');
            user.labStaff.roleKey = roleKey;
        }
        if (typeof active === 'boolean') user.labStaff.active = active;
        if (password) {
            if (String(password).length < 6) return fail(res, 400, 'Password must be at least 6 characters', 'password');
            user.password = await bcrypt.hash(String(password), 12);
        }
        await user.save();
        res.json({ success: true, data: publicStaff(user) });
    } catch (error) {
        console.error('Update staff error:', error);
        fail(res, 500, 'Error updating the account');
    }
});

// Removing a staff member keeps their history but makes the account unusable.
router.delete('/api/staff/:id', async (req, res) => {
    try {
        const user = await loadStaff(req, res);
        if (!user) return;
        if (String(user._id) === String(req.user._id)) return fail(res, 400, 'You cannot remove yourself', 'self');
        user.labStaff.active = false;
        user.labStaff.labId = null;
        user.status = 'blocked';
        user.blockReason = 'Removed from lab staff';
        user.password = await bcrypt.hash(crypto.randomBytes(24).toString('hex'), 10);
        await user.save();
        res.json({ success: true });
    } catch (error) {
        console.error('Remove staff error:', error);
        fail(res, 500, 'Error removing the account');
    }
});

module.exports = router;
