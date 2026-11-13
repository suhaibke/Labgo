// Lab staff permissions (same set as the lab app's Users & Roles).
// The lab owner always has every permission.

const PERMISSIONS = ['patients', 'results', 'tests', 'packages', 'finance', 'waste', 'store', 'users', 'settings'];

const DEFAULT_ROLES = [
    { key: 'admin', color: '#FF5A00', permissions: [...PERMISSIONS], isDefault: true },
    { key: 'technician', color: '#007AFF', permissions: ['patients', 'results', 'tests'], isDefault: true },
    { key: 'receptionist', color: '#34C759', permissions: ['patients'], isDefault: true },
    { key: 'accountant', color: '#AF52DE', permissions: ['finance'], isDefault: true },
    { key: 'guest', color: '#8E8E93', permissions: [], isDefault: true },
];

// First matching rule wins. `any` = every signed-in staff member,
// an array = at least one of these permissions. Unlisted paths are owner-only.
const RULES = [
    [/^\/(dashboard|overview)\/?$/, 'any'],
    [/^\/api\/stats$/, 'any'],
    [/^\/api\/notifications(\/read)?$/, 'any'],
    [/^\/api\/(support|market)(\/|$)/, 'any'],
    [/^\/api\/labs\/(directory|[^/]+\/quote)$/, ['patients', 'results']],
    [/^\/(api\/)?transfers\/incoming(\/|$)/, ['results', 'patients']],
    // The lab mobile app's start-up data; each screen's actions still check permissions.
    [/^\/api\/app\/(bootstrap|patients)$/, 'any'],
    [/^\/api\/app\/finance$/, ['finance']],
    [/^\/api\/app\/tests$/, ['tests']],
    [/^\/api\/app\/packages$/, ['packages']],
    [/^\/api\/app\/lab$/, ['settings']],
    [/^\/api\/app\/transfers$/, ['patients', 'results']],
    [/^\/profile\/?$/, 'any'],
    [/^\/api\/user\/profile$/, 'any'],
    [/^\/(api\/)?orders\/[^/]+\/results(\/approve)?$/, ['results']],
    [/^\/api\/orders\/[^/]+\/(complete|upload-result)$/, ['results']],
    [/^\/api\/tests\/[^/]+\/reference$/, ['results', 'tests']],
    [/^\/patients\/new$/, ['patients']],
    [/^\/api\/(walk-in-orders|patients\/lookup)$/, ['patients']],
    [/^\/(api\/)?(orders|patient-tests|external-transfers)(\/|$)/, ['patients', 'results']],
    [/^\/(api\/)?tests(\/|$)/, ['tests']],
    [/^\/(api\/)?(offers|packages|services)(\/|$)/, ['packages']],
    [/^\/(api\/)?(reports|earnings-report|transactions|finance)(\/|$)/, ['finance']],
    [/^\/(api\/)?waste(\/|$)/, ['waste']],
    [/^\/(users|api\/staff)(\/|$)/, ['users']],
    [/^\/(settings|api\/profile|api\/upload-logo)(\/|$)/, ['settings']],
];

function requiredFor(path) {
    for (const [re, need] of RULES) {
        if (re.test(path)) return need;
    }
    return 'owner';
}

function canAccess(path, permissions, isOwner) {
    if (isOwner) return true;
    const need = requiredFor(path);
    if (need === 'any') return true;
    if (need === 'owner') return false;
    return need.some((p) => permissions.includes(p));
}

// Lab roles = built-in roles + the lab's own, with the lab's overrides.
function labRoles(lab) {
    const saved = Array.isArray(lab?.staffRoles) ? lab.staffRoles : [];
    const byKey = new Map(saved.map((r) => [r.key, r]));
    const builtIn = DEFAULT_ROLES.map((r) => {
        const s = byKey.get(r.key);
        return { ...r, name: s?.name || '', permissions: s ? s.permissions.filter((p) => PERMISSIONS.includes(p)) : r.permissions };
    });
    const custom = saved
        .filter((r) => !DEFAULT_ROLES.some((d) => d.key === r.key))
        .map((r) => ({ key: r.key, name: r.name, color: r.color || '#8E8E93', permissions: (r.permissions || []).filter((p) => PERMISSIONS.includes(p)), isDefault: false }));
    // The manager role always keeps every permission.
    builtIn[0].permissions = [...PERMISSIONS];
    return builtIn.concat(custom);
}

// The landing page for a staff member who cannot see the dashboard pages they open.
function homeFor(permissions, isOwner) {
    if (isOwner) return '/lab/dashboard';
    if (permissions.includes('patients')) return '/lab/patients/new';
    if (permissions.includes('results')) return '/lab/orders';
    return '/lab/dashboard';
}

module.exports = { PERMISSIONS, DEFAULT_ROLES, requiredFor, canAccess, labRoles, homeFor };
