// The signing key for login tokens (and, by default, report / label links).
// It must come from the environment: a key written in the code is public to
// anyone who can read the repository and would let them sign tokens.
const DEV_ONLY_SECRET = 'labgo-local-development-only-secret';

function jwtSecret() {
    const v = process.env.JWT_SECRET;
    if (v) return v;
    if (process.env.NODE_ENV === 'production') {
        throw new Error('JWT_SECRET is not set. Set it in the server environment (e.g. a long random string from `openssl rand -hex 64`).');
    }
    return DEV_ONLY_SECRET;
}

// Called once at start-up so a production server without the key stops with a clear message.
function assertSecrets() {
    jwtSecret();
}

module.exports = { jwtSecret, assertSecrets };
