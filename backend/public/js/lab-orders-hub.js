/* Send & receive (lab web dashboard) — the lab app's page, on the web.
 *
 * Send: one form in four steps (patient → tests → receiving lab → send) and the
 * tracking list with its search. Receive: a barcode box and the received
 * samples — LabGo service orders and samples other labs sent here — with search.
 * It uses the same server APIs as the lab app, so both stay in step. */
(function () {
    'use strict';

    const D = JSON.parse(document.getElementById('srData').textContent || '{}');
    const t = D.t || {};
    const $ = (id) => document.getElementById(id);
    const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => Number(n || 0).toLocaleString('en-US');
    const digits = (s) => String(s || '').replace(/[^0-9]/g, '');
    const norm = (s) => String(s || '').toLowerCase().trim();
    // Day/month/year in Western digits, without the hidden direction marks of an Arabic date string.
    const day = (d) => {
        if (!d) return '';
        const x = new Date(d);
        return Number.isNaN(x.getTime()) ? '' : `${x.getDate()}/${x.getMonth() + 1}/${x.getFullYear()}`;
    };
    const code = (c) => (c ? `<span class="sr-code">${esc(c)}</span>` : '');

    async function api(url, opts) {
        const res = await fetch(url, Object.assign({ headers: { Accept: 'application/json' } }, opts || {}));
        const body = await res.json().catch(() => ({}));
        if (!res.ok || body.success === false) {
            const err = new Error(body.message || t.error);
            err.status = res.status;
            err.code = body.code;
            throw err;
        }
        return body.data !== undefined ? body.data : body;
    }
    const postJson = (url, data) => api(url, { method: 'POST', headers: { 'Content-Type': 'application/json', Accept: 'application/json' }, body: JSON.stringify(data) });

    function toast(message, type) {
        const box = $('toastContainer');
        if (!box || !message) return;
        const el = document.createElement('div');
        el.className = `la-toast ${type || 'info'}`;
        el.innerHTML = '<span class="dot"></span><span class="toast-message"></span>';
        el.querySelector('.toast-message').textContent = message;
        box.appendChild(el);
        setTimeout(() => { el.classList.add('removing'); setTimeout(() => el.remove(), 300); }, 4000);
    }

    // ------------------------------------------------------------------ tabs
    const tabs = [...document.querySelectorAll('#srTabs [data-tab]')];
    function showTab(name) {
        tabs.forEach((b) => { const on = b.dataset.tab === name; b.classList.toggle('on', on); b.setAttribute('aria-selected', String(on)); });
        document.querySelectorAll('.sr-pane').forEach((p) => { p.hidden = p.dataset.pane !== name; });
        const url = new URL(location.href);
        url.searchParams.set('tab', name);
        url.searchParams.delete('orderId');
        history.replaceState(null, '', url);
        if (name === 'receive') { $('scanInput').focus(); loadReceived(); }
    }
    tabs.forEach((b) => b.addEventListener('click', () => showTab(b.dataset.tab)));

    // ------------------------------------------------------- dropdown helper
    // A search field with a floating list under it (like the app's FloatingDropdown).
    function combo(input, list, render) {
        let items = [];
        let active = -1;
        function close() { list.hidden = true; active = -1; }
        function paint() {
            list.innerHTML = items.map((it, i) => `<button type="button" role="option" class="sr-opt${i === active ? ' on' : ''}${it.accent ? ' accent' : ''}" data-i="${i}">${it.html}</button>`).join('');
            list.hidden = !items.length;
        }
        async function update() {
            items = await render(input.value);
            active = -1;
            paint();
        }
        input.addEventListener('input', update);
        input.addEventListener('focus', update);
        input.addEventListener('keydown', (e) => {
            if (list.hidden) return;
            if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
                e.preventDefault();
                active = (active + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length;
                paint();
            } else if (e.key === 'Enter') {
                const pick = items[active >= 0 ? active : 0];
                if (pick) { e.preventDefault(); pick.pick(); close(); }
            } else if (e.key === 'Escape') close();
        });
        list.addEventListener('mousedown', (e) => e.preventDefault()); // keep focus while choosing
        list.addEventListener('click', (e) => {
            const b = e.target.closest('[data-i]');
            if (!b) return;
            items[Number(b.dataset.i)].pick();
            close();
        });
        input.addEventListener('blur', () => setTimeout(close, 120));
        return { close, update };
    }

    // ================================================================ SEND
    const form = {
        orderId: null, // an open order of a registered patient
        gender: '',
        tests: [], // picked test names
        registered: [], // the picked patient's tests
        lab: null, // { id, name, city } or { name } for a lab not on LabGo
        priceEdited: false,
    };
    let patients = [];
    async function loadPatients() {
        try { patients = (await api('/lab/api/app/patients')).patients || []; } catch (e) { patients = []; }
    }

    // 1. patient
    const patientInput = $('patientInput');
    function setGender(g) {
        form.gender = g;
        document.querySelectorAll('.sr-gender [data-gender]').forEach((b) => b.classList.toggle('on', b.dataset.gender === g));
    }
    document.querySelectorAll('.sr-gender [data-gender]').forEach((b) => b.addEventListener('click', () => setGender(form.gender === b.dataset.gender ? '' : b.dataset.gender)));
    $('ageInput').addEventListener('input', (e) => { e.target.value = digits(e.target.value).slice(0, 3); });

    function syncPhoneRow() {
        $('phoneRow').hidden = Boolean(form.orderId) || !patientInput.value.trim();
    }
    function pickPatient(p) {
        patientInput.value = p.name;
        form.orderId = p.status === 'Completed' ? null : p.id;
        $('phoneInput').value = form.orderId ? '' : (p.phone || '');
        $('ageInput').value = digits(p.age);
        setGender(p.gender === 'Female' ? 'female' : p.gender === 'Male' ? 'male' : '');
        form.registered = form.orderId ? (p.tests || []) : [];
        renderRegistered();
        syncPhoneRow();
        refreshQuote();
    }
    combo(patientInput, $('patientList'), (q) => {
        const s = norm(q);
        if (!s) return [];
        return patients
            .filter((p) => norm(p.name).includes(s) || norm(p.phone).includes(s) || norm(p.permanent).includes(s))
            .slice(0, 8)
            .map((p) => ({
                html: `<b>${esc(p.name)}</b><small>${esc([p.permanent, p.phone, (p.tests || []).slice(0, 3).join('، ')].filter(Boolean).join(' · '))}</small>`,
                pick: () => pickPatient(p),
            }));
    });
    patientInput.addEventListener('input', () => {
        // Typing again after a pick: a new name (the earlier order no longer applies).
        form.orderId = null;
        form.registered = [];
        renderRegistered();
        syncPhoneRow();
    });

    // 2. tests
    function renderRegistered() {
        const free = form.registered.filter((n) => !form.tests.includes(n));
        $('registeredBox').hidden = !free.length;
        $('registeredTests').innerHTML = free.map((n) => `<button type="button" class="sr-chip" data-add="${esc(n)}"><svg class="ic"><use href="#i-plus"/></svg>${esc(n)}</button>`).join('');
    }
    function renderPicked() {
        $('pickedTests').innerHTML = form.tests.map((n) => `<span class="sr-chip on">${esc(n)}<button type="button" data-remove="${esc(n)}" aria-label="×"><svg class="ic"><use href="#i-x"/></svg></button></span>`).join('');
        renderRegistered();
    }
    function addTest(name) {
        const n = String(name || '').trim();
        if (!n || form.tests.some((x) => norm(x) === norm(n))) return;
        form.tests.push(n);
        renderPicked();
        refreshQuote();
    }
    $('registeredTests').addEventListener('click', (e) => { const b = e.target.closest('[data-add]'); if (b) addTest(b.dataset.add); });
    $('pickedTests').addEventListener('click', (e) => {
        const b = e.target.closest('[data-remove]');
        if (!b) return;
        form.tests = form.tests.filter((x) => x !== b.dataset.remove);
        renderPicked();
        refreshQuote();
    });
    const testInput = $('testInput');
    combo(testInput, $('testList'), (q) => {
        const s = norm(q);
        if (!s) return [];
        const hits = (D.catalog || []).filter((n) => norm(n).includes(s) && !form.tests.includes(n)).slice(0, 8)
            .map((n) => ({ html: `<b>${esc(n)}</b>`, pick: () => { addTest(n); testInput.value = ''; } }));
        // A test this lab does not have can still be sent by name.
        if (!(D.catalog || []).some((n) => norm(n) === s)) {
            hits.push({ html: `<b>${esc(t.addTest)}: ${esc(q.trim())}</b>`, accent: true, pick: () => { addTest(q); testInput.value = ''; } });
        }
        return hits;
    });

    // 3. lab + price
    const labInput = $('labInput');
    let labTimer = null;
    combo(labInput, $('labList'), (q) => new Promise((resolve) => {
        clearTimeout(labTimer);
        labTimer = setTimeout(async () => {
            let labs = [];
            try { labs = (await api(`/lab/api/labs/directory?q=${encodeURIComponent(q.trim())}`)).labs || []; } catch (e) { /* offline */ }
            const items = labs.slice(0, 8).map((l) => ({
                html: `<b>${esc(l.name)}</b><small>${esc([l.city, l.phone].filter(Boolean).join(' · '))}</small>`,
                pick: () => chooseLab({ id: l.id, name: l.name, city: l.city || '', phone: l.phone || '' }),
            }));
            const typed = q.trim();
            if (typed && !labs.some((l) => norm(l.name) === norm(typed))) {
                items.push({ html: `<b>${esc(t.useLab)}: ${esc(typed)}</b><small>${esc(t.notOnLabgo)}</small>`, accent: true, pick: () => chooseLab({ name: typed }) });
            }
            resolve(items);
        }, q.trim() ? 220 : 0);
    }));
    function chooseLab(l) {
        form.lab = l;
        labInput.value = '';
        form.priceEdited = false;
        $('priceInput').value = '';
        renderLab();
        refreshQuote();
    }
    function renderLab() {
        const l = form.lab;
        $('labChosen').innerHTML = l ? `<div class="sr-lab">
                <span class="sr-lab-ic"><svg class="ic"><use href="#i-building-2"/></svg></span>
                <span class="sr-lab-main"><b>${esc(l.name)}</b><small>${esc(l.id ? [l.city, l.phone].filter(Boolean).join(' · ') : t.notOnLabgo)}</small></span>
                ${l.id ? '<span class="sr-labgo">LabGo</span>' : ''}
                <button type="button" class="la-icon-btn press-90" id="labRemove" aria-label="×"><svg class="ic"><use href="#i-x"/></svg></button>
            </div>` : '';
        $('priceBox').hidden = !l;
        $('priceHint').textContent = l && !l.id ? t.priceTyped : '';
        const rm = $('labRemove');
        if (rm) rm.addEventListener('click', () => { form.lab = null; renderLab(); labInput.focus(); });
    }
    $('priceInput').addEventListener('input', (e) => {
        form.priceEdited = true;
        const d = digits(e.target.value);
        e.target.value = d ? money(d) : '';
    });
    let quoteTimer = null;
    function refreshQuote() {
        clearTimeout(quoteTimer);
        quoteTimer = setTimeout(async () => {
            const l = form.lab;
            if (!l || !l.id || form.priceEdited) return;
            $('priceHint').classList.remove('warn');
            if (!form.tests.length) { $('priceInput').value = ''; $('priceHint').textContent = t.priceAuto; return; }
            try {
                const q = await api(`/lab/api/labs/${encodeURIComponent(l.id)}/quote?tests=${encodeURIComponent(form.tests.join(','))}`);
                $('priceInput').value = q.lines.length ? money(q.total) : '';
                $('priceHint').textContent = q.missing.length ? `${t.priceMissing}: ${q.missing.join('، ')}` : t.priceAuto;
                $('priceHint').classList.toggle('warn', q.missing.length > 0);
            } catch (e) { /* the price can still be typed */ }
        }, 250);
    }

    // 4. send
    function resetForm() {
        Object.assign(form, { orderId: null, gender: '', tests: [], registered: [], lab: null, priceEdited: false });
        ['patientInput', 'phoneInput', 'ageInput', 'testInput', 'labInput', 'priceInput'].forEach((id) => { $(id).value = ''; });
        setGender('');
        renderPicked();
        renderLab();
        syncPhoneRow();
    }
    $('sendForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const name = patientInput.value.trim();
        const phone = $('phoneInput').value.trim();
        if (!name) { toast(t.needName, 'error'); patientInput.focus(); return; }
        if (!form.orderId && !digits(phone)) { toast(t.needPhone, 'error'); syncPhoneRow(); $('phoneInput').focus(); return; }
        if (!form.tests.length) { toast(t.needTests, 'error'); testInput.focus(); return; }
        if (!form.lab) { toast(t.needLab, 'error'); labInput.focus(); return; }
        const body = {
            patientName: name,
            patientPhone: phone,
            patientGender: form.gender,
            patientAge: $('ageInput').value,
            testNames: form.tests,
            labName: form.lab.name,
        };
        if (form.orderId) body.orderId = form.orderId;
        if (form.lab.id) body.toLabId = form.lab.id;
        if (form.priceEdited && digits($('priceInput').value)) body.price = Number(digits($('priceInput').value));
        if (!form.lab.id && digits($('priceInput').value)) body.price = Number(digits($('priceInput').value));
        const btn = $('sendBtn');
        btn.disabled = true;
        try {
            await postJson('/lab/api/app/transfers', body);
            toast(t.sent, 'success');
            resetForm();
            loadPatients();
            loadTracking();
        } catch (err) {
            toast(err.code === 'alreadySent' ? t.alreadySent : err.code === 'phone' ? t.needPhone : (err.message || t.error), 'error');
        }
        btn.disabled = false;
    });

    // ------------------------------------------------------------ tracking
    let referrals = [];
    function steps(r) {
        const done = r.status === 'Completed';
        const received = done || Boolean(r.receivedAt);
        const s = (cls, label) => `<li class="${cls}"><span></span>${esc(label)}</li>`;
        const now = done ? 2 : received ? 1 : 0; // the stage the sample is at now
        const cls = (i, reached, skip) => (i === now ? 'done now' : reached ? 'done' : skip ? 'skip' : '');
        return `<ol class="sr-steps">${s(cls(0, true), t.stepSent)}${s(cls(1, received, !r.onLabGo), t.stepReceived)}${s(cls(2, done), t.stepResult)}</ol>`;
    }
    function trackCard(r) {
        const done = r.status === 'Completed';
        const label = `/lab/external-transfers/${encodeURIComponent(r.id)}/label?lang=${D.labelLang}`;
        let main = '';
        if (!done) {
            main = `<button type="button" class="la-btn sm press-95" data-act="upload" data-id="${esc(r.id)}"><svg class="ic"><use href="#i-upload"/></svg>${esc(t.uploadResult)}</button>`;
        } else {
            if (r.resultFile) main += `<a class="la-btn sm soft press-95" href="${esc(r.resultFile)}" target="_blank" rel="noopener"><svg class="ic"><use href="#i-file-down"/></svg>${esc(t.viewResult)}</a>`;
            if (r.orderId && !r.forwardedAt && (r.resultSource === 'external_link' || r.resultSource === 'receiving_lab')) {
                main += `<button type="button" class="la-btn sm press-95" data-act="forward" data-id="${esc(r.id)}"><svg class="ic flip-rtl"><use href="#i-send"/></svg>${esc(t.toPatient)}</button>`;
            } else if (r.forwardedAt) {
                main += `<span class="sr-done-note"><svg class="ic"><use href="#i-check"/></svg>${esc(t.sentToPatient)}</span>`;
            }
        }
        return `<article class="la-card sr-card" data-id="${esc(r.id)}">
            <div class="sr-card-top">
                <b class="sr-card-name"><bdi>${esc(r.patient)}</bdi> · <bdi>${esc(r.test)}</bdi></b>
                <span class="sr-status ${done ? 'done' : 'wait'}">${esc(done ? t.statusDone : t.statusSent)}</span>
            </div>
            <p class="sr-card-meta"><bdi>${esc(r.lab)}</bdi>${r.onLabGo ? '<span class="sr-labgo">LabGo</span>' : ''}${r.eta && r.eta !== '—' ? `<span>${esc(t.eta)} <span class="num">${esc(r.eta)}</span></span>` : ''}</p>
            <p class="sr-card-meta">${code(r.tracking)}${typeof r.price === 'number' ? `<span class="num">${money(r.price)} ${esc(t.currency)}</span>` : ''}<span class="num">${esc(day(r.sentAt))}</span></p>
            ${steps(r)}
            <div class="sr-card-foot">
                <div class="sr-icons">
                    <a class="la-icon-btn press-90" href="${label}" target="_blank" rel="noopener" title="${esc(t.printLabel)}" aria-label="${esc(t.printLabel)}"><svg class="ic"><use href="#i-printer"/></svg></a>
                    <button type="button" class="la-icon-btn press-90" data-act="pdf" data-id="${esc(r.id)}" data-code="${esc(r.tracking)}" title="${esc(t.labelPdf)}" aria-label="${esc(t.labelPdf)}"><svg class="ic"><use href="#i-file-down"/></svg></button>
                    <button type="button" class="la-icon-btn press-90 sr-danger" data-act="delete" data-id="${esc(r.id)}" title="${esc(t.del)}" aria-label="${esc(t.del)}"><svg class="ic"><use href="#i-trash-2"/></svg></button>
                </div>
                <div class="sr-main-actions">${main}</div>
            </div>
        </article>`;
    }
    function renderTracking() {
        const q = norm($('trackSearch').value);
        const list = referrals.filter((r) => !q || norm([r.patient, r.test, r.lab, r.tracking, r.sampleCode].join(' ')).includes(q));
        $('trackCount').textContent = referrals.length;
        $('trackList').innerHTML = list.length ? list.map(trackCard).join('')
            : `<div class="la-empty-box"><svg class="ic"><use href="#i-${referrals.length ? 'search' : 'send'}"/></svg><p>${esc(referrals.length ? t.noMatch : t.noTracking)}</p></div>`;
    }
    async function loadTracking() {
        try { referrals = (await api('/lab/api/app/transfers')).referrals || []; } catch (e) { /* keep the last list */ }
        renderTracking();
    }
    $('trackSearch').addEventListener('input', renderTracking);

    // result file picker shared by every card
    const fileInput = $('resultFile');
    let uploadTarget = null; // { kind: 'sent' | 'order' | 'lab', id }
    function pickFile(target) { uploadTarget = target; fileInput.value = ''; fileInput.click(); }
    fileInput.addEventListener('change', async () => {
        const file = fileInput.files[0];
        const target = uploadTarget;
        if (!file || !target) return;
        if (file.size > 5 * 1024 * 1024) { toast(t.fileTooBig, 'error'); return; }
        const fd = new FormData();
        fd.append('resultFile', file);
        try {
            if (target.kind === 'sent') {
                await api(`/lab/api/external-transfers/${encodeURIComponent(target.id)}/result`, { method: 'POST', body: fd });
                loadTracking();
            } else if (target.kind === 'order') {
                const up = await api(`/lab/api/orders/${encodeURIComponent(target.id)}/upload-result`, { method: 'POST', body: fd });
                await postJson(`/lab/api/orders/${encodeURIComponent(target.id)}/complete`, { reportUrl: up.fileUrl });
                loadReceived();
            } else {
                await api(`/lab/api/transfers/incoming/${encodeURIComponent(target.id)}/upload-result?finish=1`, { method: 'POST', body: fd });
                loadReceived();
            }
            toast(t.uploaded, 'success');
        } catch (err) { toast(err.message || t.error, 'error'); }
    });

    $('trackList').addEventListener('click', async (e) => {
        const b = e.target.closest('[data-act]');
        if (!b) return;
        const id = b.dataset.id;
        if (b.dataset.act === 'upload') pickFile({ kind: 'sent', id });
        else if (b.dataset.act === 'pdf') {
            b.disabled = true;
            try {
                const res = await fetch(`/lab/api/external-transfers/${encodeURIComponent(id)}/label.pdf?lang=${D.labelLang}`);
                if (!res.ok) throw new Error();
                const url = URL.createObjectURL(await res.blob());
                const a = Object.assign(document.createElement('a'), { href: url, download: `label-${b.dataset.code || 'sample'}.pdf` });
                document.body.appendChild(a); a.click(); a.remove();
                setTimeout(() => URL.revokeObjectURL(url), 5000);
            } catch (err) {
                window.open(`/lab/external-transfers/${encodeURIComponent(id)}/label?lang=${D.labelLang}`, '_blank'); // no PDF engine: printable page
            }
            b.disabled = false;
        } else if (b.dataset.act === 'forward') {
            b.disabled = true;
            try { await api(`/lab/api/external-transfers/${encodeURIComponent(id)}/forward`, { method: 'POST' }); toast(t.forwarded, 'success'); loadTracking(); }
            catch (err) { b.disabled = false; toast(err.message || t.error, 'error'); }
        } else if (b.dataset.act === 'delete') {
            if (!window.confirm(t.confirmDel)) return;
            b.disabled = true;
            try {
                await api(`/lab/api/app/transfers/${encodeURIComponent(id)}`, { method: 'DELETE' });
                referrals = referrals.filter((r) => r.id !== id);
                const card = b.closest('.sr-card');
                card.classList.add('leaving');
                setTimeout(renderTracking, 200);
                toast(t.deleted, 'success');
            } catch (err) { b.disabled = false; toast(err.message || t.error, 'error'); }
        }
    });

    // ============================================================= RECEIVE
    // One list: LabGo service orders (patients via the LabGo app) and samples other labs sent.
    let received = [];
    let recvFilter = 'all';
    function fromOrder(o) {
        const p = o.patientInfo || {};
        return {
            kind: 'order', id: String(o._id), code: o.qrCode || '', patient: p.name || '',
            demo: [p.gender ? t[p.gender] : '', Number.isInteger(p.age) ? `${p.age} ${t.years}` : ''].filter(Boolean).join(' · '),
            tests: (o.tests || []).map((x) => (typeof x === 'string' ? x : x.testName)).filter(Boolean),
            source: t.fromLabgo, status: o.status === 'sample_collected' ? 'on_the_way' : o.status === 'completed' ? 'completed' : 'received',
            at: o.updatedAt || o.createdAt, fileUrl: '',
        };
    }
    function fromLab(s) {
        return {
            kind: 'lab', id: s.id, code: s.code, patient: s.patient,
            demo: [s.gender ? t[s.gender] : '', s.age !== null && s.age !== undefined ? `${s.age} ${t.years}` : ''].filter(Boolean).join(' · '),
            tests: s.tests || [], source: `${t.fromLab} ${s.fromLab}`, status: s.status,
            at: s.receivedAt || s.sentAt, fileUrl: s.fileUrl || `/lab/api/transfers/incoming/${s.id}/report.pdf`, price: s.price,
        };
    }
    function recvCard(r) {
        const pill = { on_the_way: ['wait', t.onWay], received: ['in', t.inLab], completed: ['done', t.done] }[r.status] || ['', ''];
        let actions = '';
        if (r.status === 'on_the_way') {
            actions = `<button type="button" class="la-btn sm press-95" data-recv="${esc(r.kind)}" data-code="${esc(r.code)}"><svg class="ic"><use href="#i-check"/></svg>${esc(t.receiveBtn)}</button>`;
        } else if (r.status === 'received') {
            const href = r.kind === 'order' ? `/lab/orders/${encodeURIComponent(r.id)}/results` : `/lab/transfers/incoming/${encodeURIComponent(r.id)}/results`;
            actions = `<a class="la-btn sm press-95" href="${href}"><svg class="ic"><use href="#i-file-text"/></svg>${esc(t.enterResult)}</a>`
                + `<button type="button" class="la-btn sm soft press-95" data-file="${esc(r.kind)}" data-id="${esc(r.id)}"><svg class="ic"><use href="#i-upload"/></svg>PDF</button>`;
        } else if (r.fileUrl) {
            actions = `<a class="la-btn sm soft press-95" href="${esc(r.fileUrl)}" target="_blank" rel="noopener"><svg class="ic"><use href="#i-file-down"/></svg>${esc(t.viewResult)}</a>`;
        }
        return `<article class="la-card sr-card">
            <div class="sr-card-top">
                <span class="la-avatar">${esc((r.patient || '?').trim().charAt(0).toUpperCase())}</span>
                <span class="sr-card-who"><b class="sr-card-name"><bdi>${esc(r.patient)}</bdi></b><small>${esc(r.demo || '')}</small></span>
                <span class="sr-status ${pill[0]}">${esc(pill[1])}</span>
            </div>
            <p class="sr-source ${r.kind}">${code(r.code)}<svg class="ic"><use href="#i-${r.kind === 'order' ? 'smartphone' : 'building-2'}"/></svg><bdi>${esc(r.source)}</bdi>${typeof r.price === 'number' ? `<span class="sr-price">${money(r.price)} ${esc(t.currency)}</span>` : ''}</p>
            ${r.tests.length ? `<div class="la-tags">${r.tests.slice(0, 6).map((n) => `<span class="la-tag"><svg class="ic"><use href="#i-test-tube"/></svg>${esc(n)}</span>`).join('')}</div>` : ''}
            <div class="sr-card-foot">
                <span class="sr-card-meta"><svg class="ic"><use href="#i-clock"/></svg><span class="num">${esc(day(r.at))}</span></span>
                <div class="sr-main-actions">${actions}</div>
            </div>
        </article>`;
    }
    function renderReceived() {
        const q = norm($('recvSearch').value);
        const list = received.filter((r) => (recvFilter === 'all' || r.status === recvFilter)
            && (!q || norm([r.patient, r.code, r.source, r.tests.join(' ')].join(' ')).includes(q)));
        $('recvCount').textContent = received.length;
        const waiting = received.filter((r) => r.status === 'on_the_way').length;
        $('receiveBadge').hidden = !waiting;
        $('receiveBadge').textContent = waiting;
        $('recvList').innerHTML = list.length ? list.map(recvCard).join('')
            : `<div class="la-empty-box"><svg class="ic"><use href="#i-${received.length ? 'search' : 'inbox'}"/></svg><p>${esc(received.length ? t.noMatch : t.noReceived)}</p></div>`;
    }
    async function loadReceived() {
        const [orders, labs] = await Promise.all([
            api('/lab/api/orders?status=active&limit=100').then((d) => d.orders || []).catch(() => null),
            api('/lab/api/transfers/incoming').then((d) => d.items || []).catch(() => null),
        ]);
        if (orders === null && labs === null) { renderReceived(); return; }
        const order = { on_the_way: 0, received: 1, completed: 2 }; // what needs doing first
        received = [
            ...(orders || []).filter((o) => o.orderType !== 'walk_in').map(fromOrder),
            ...(labs || []).map(fromLab),
        ].sort((a, b) => (order[a.status] - order[b.status]) || (new Date(b.at) - new Date(a.at)));
        renderReceived();
    }
    $('recvSearch').addEventListener('input', renderReceived);
    document.querySelectorAll('#recvFilters [data-f]').forEach((c) => c.addEventListener('click', () => {
        recvFilter = c.dataset.f;
        document.querySelectorAll('#recvFilters [data-f]').forEach((x) => x.classList.toggle('on', x === c));
        renderReceived();
    }));

    // receiving: a LabGo order's QR, or another lab's tracking / sample code
    async function receiveCode(code, kindHint) {
        const tracking = /^T[A-Z0-9]{6}$/i.test(code);
        if (kindHint !== 'order' && (tracking || kindHint === 'lab')) {
            await postJson('/lab/api/transfers/incoming/receive', { code });
            return;
        }
        try {
            await postJson('/lab/api/orders/scan-qr', { qrCode: code });
        } catch (err) {
            if (kindHint === 'order') throw err;
            try { await postJson('/lab/api/transfers/incoming/receive', { code }); } // maybe a sample code from another lab
            catch (e2) { throw Object.assign(new Error(t.notFound), { notFound: true }); }
        }
    }
    $('scanForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const input = $('scanInput');
        const code = input.value.trim();
        if (!code) { input.focus(); return; }
        $('scanBtn').disabled = true;
        try {
            await receiveCode(code);
            toast(t.received, 'success');
            input.value = '';
            loadReceived();
        } catch (err) {
            toast(err.notFound || err.status === 404 ? t.notFound : (err.message || t.error), 'error');
            input.select();
        }
        $('scanBtn').disabled = false;
    });
    $('recvList').addEventListener('click', async (e) => {
        const r = e.target.closest('[data-recv]');
        if (r) {
            r.disabled = true;
            try { await receiveCode(r.dataset.code, r.dataset.recv); toast(t.received, 'success'); loadReceived(); }
            catch (err) { r.disabled = false; toast(err.message || t.error, 'error'); }
            return;
        }
        const f = e.target.closest('[data-file]');
        if (f) pickFile({ kind: f.dataset.file, id: f.dataset.id });
    });

    // ---------------------------------------------------------------- start
    (async function start() {
        loadTracking();
        loadReceived(); // also fills the badge on the Receive tab
        await loadPatients();
        // "Send to lab" from an order page: that patient is picked already.
        if (D.preselectOrderId) {
            const p = patients.find((x) => x.id === D.preselectOrderId);
            if (p) { pickPatient(p); (p.tests || []).forEach(addTest); }
        }
    })();
})();
