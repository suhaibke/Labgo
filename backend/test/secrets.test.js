const assert = require('node:assert/strict');
const test = require('node:test');
const { jwtSecret, assertSecrets } = require('../config/secrets');

test('production refuses to run without JWT_SECRET; nothing is hard-coded', () => {
    const saved = { env: process.env.NODE_ENV, key: process.env.JWT_SECRET };
    try {
        delete process.env.JWT_SECRET;
        process.env.NODE_ENV = 'production';
        assert.throws(() => assertSecrets(), /JWT_SECRET is not set/);
        process.env.JWT_SECRET = 'from-env';
        assert.equal(jwtSecret(), 'from-env');
        delete process.env.JWT_SECRET;
        process.env.NODE_ENV = 'development';
        assert.match(jwtSecret(), /development-only/);
    } finally {
        if (saved.env === undefined) delete process.env.NODE_ENV; else process.env.NODE_ENV = saved.env;
        if (saved.key === undefined) delete process.env.JWT_SECRET; else process.env.JWT_SECRET = saved.key;
    }
});
