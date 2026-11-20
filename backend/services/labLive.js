// Live sync between the lab's devices (web dashboard ⇄ mobile app).
//
// Every successful change a lab makes (from the app or the web, through the same
// /lab routes and the same permission checks) is published here as a small event:
// what kind of data changed, never the data itself. Each open web dashboard gets
// it over Server-Sent Events and reloads that data through its normal, permission-
// checked pages. The app keeps its own refresh (foreground, tab change, 2 minutes).
//
// One Node process serves the site (Dockerfile: `node app.js`), so an in-memory
// bus is enough. Events carry a per-lab sequence number; a reconnecting page
// sends Last-Event-ID and gets what it missed, or `resync` when too much was missed
// or the server restarted (new bootId).

const { EventEmitter } = require('events');
const crypto = require('crypto');
const { canAccess } = require('../helpers/lab-permissions');

const bus = new EventEmitter();
bus.setMaxListeners(0);

const BOOT_ID = crypto.randomBytes(6).toString('hex');
const KEEP = 200; // events kept per lab for reconnect replay
const history = new Map(); // labId -> [{ seq, evt }]
const seqs = new Map(); // labId -> last seq

/** What part of the lab a path changes (used by pages to decide what to refresh). */
function kindOf(path) {
    const p = String(path || '');
    if (/\/(staff|users)\b/.test(p)) return 'staff';
    if (/\/(results|upload-result|complete|approve)\b/.test(p) || /\/transfers\/[^/]+\/results/.test(p)) return 'results';
    if (/\/(transfers|external-transfers)\b/.test(p)) return 'transfers';
    if (/\/(orders|walk-in-orders|patients|patient-tests)\b/.test(p)) return 'orders';
    if (/\/tests\b/.test(p)) return 'tests';
    if (/\/(packages|offers|services)\b/.test(p)) return 'packages';
    if (/\/(finance|expenses|transactions|pay)\b/.test(p)) return 'finance';
    if (/\/waste\b/.test(p)) return 'waste';
    if (/\/maintenance\b/.test(p)) return 'maintenance';
    if (/\/(profile|settings|lab|upload-logo)\b/.test(p)) return 'lab';
    if (/\/(market|supplies|support)\b/.test(p)) return 'store';
    return 'other';
}

/**
 * Publishes one change for a lab.
 * evt: { kind, path, method, source: 'app'|'web'|'server', by, client }
 */
function publish(labId, evt) {
    if (!labId) return null;
    const id = String(labId);
    const seq = (seqs.get(id) || 0) + 1;
    seqs.set(id, seq);
    const full = { seq, at: new Date().toISOString(), kind: evt.kind || kindOf(evt.path), ...evt };
    const list = history.get(id) || [];
    list.push(full);
    if (list.length > KEEP) list.splice(0, list.length - KEEP);
    history.set(id, list);
    bus.emit(`lab:${id}`, full);
    return full;
}

/** Events after `afterSeq`, or null when they are no longer all kept. */
function since(labId, afterSeq) {
    const list = history.get(String(labId)) || [];
    if (!list.length) return afterSeq >= (seqs.get(String(labId)) || 0) ? [] : null;
    if (afterSeq < list[0].seq - 1) return null;
    return list.filter((e) => e.seq > afterSeq);
}

/** Closes every live connection of a lab (after a staff/role change, so each one re-checks its access). */
function reauth(labId) {
    bus.emit(`reauth:${String(labId)}`);
}

/**
 * Express middleware (mounted after the lab auth middleware): when a change
 * request succeeds, publish it for the lab.
 */
function track(req, res, next) {
    if (!['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method) || !req.lab) return next();
    const labId = req.lab._id;
    const path = req.path;
    res.on('finish', () => {
        if (res.statusCode >= 400) return;
        if (/^\/api\/(live|notifications)(\/|$)/.test(path)) return; // reading marks, not data
        const bearer = /^Bearer /.test(req.header('Authorization') || '');
        const kind = kindOf(path);
        publish(labId, {
            kind,
            path,
            method: req.method,
            source: bearer ? 'app' : 'web',
            by: String(req.user?._id || ''),
            client: String(req.header('X-Live-Client') || '').slice(0, 40),
        });
        if (kind === 'staff') reauth(labId);
    });
    next();
}

/** GET /lab/api/live — the Server-Sent Events stream for the signed-in lab. */
function stream(req, res) {
    const labId = String(req.lab._id);
    const perms = req.labPermissions || [];
    const isOwner = Boolean(req.isLabOwner);
    // A staff member only hears about what they are allowed to open.
    const allowed = (e) => isOwner || e.kind === 'staff' || canAccess(e.path || '', perms, isOwner);

    res.set({
        'Content-Type': 'text/event-stream; charset=utf-8',
        'Cache-Control': 'no-cache, no-transform',
        Connection: 'keep-alive',
        'X-Accel-Buffering': 'no', // nginx: do not buffer the stream
    });
    res.flushHeaders?.();
    const write = (s) => {
        res.write(s);
        res.flush?.();
    };
    const send = (e) => {
        if (allowed(e)) write(`id: ${BOOT_ID}.${e.seq}\nevent: change\ndata: ${JSON.stringify(e)}\n\n`);
    };

    write(`retry: 3000\nevent: hello\ndata: ${JSON.stringify({ bootId: BOOT_ID, seq: seqs.get(labId) || 0 })}\n\n`);

    // Reconnect: replay what was missed, or ask the page to reload everything.
    const last = String(req.header('Last-Event-ID') || req.query.lastEventId || '');
    if (last) {
        const [boot, seqStr] = last.split('.');
        const after = Number(seqStr);
        const missed = boot === BOOT_ID && Number.isFinite(after) ? since(labId, after) : null;
        if (missed === null) write(`event: resync\ndata: {}\n\n`);
        else missed.forEach(send);
    }

    const onChange = (e) => send(e);
    const onReauth = () => {
        write(`event: reauth\ndata: {}\n\n`);
        res.end();
    };
    bus.on(`lab:${labId}`, onChange);
    bus.on(`reauth:${labId}`, onReauth);
    const ping = setInterval(() => write(`: ping\n\n`), 25000);
    req.on('close', () => {
        clearInterval(ping);
        bus.off(`lab:${labId}`, onChange);
        bus.off(`reauth:${labId}`, onReauth);
    });
}

module.exports = { publish, since, reauth, track, stream, kindOf, BOOT_ID, _bus: bus };
