/* Orders & transfers page (lab web dashboard).
 *
 * The patient-order columns are drawn by lab-orders.js. This file adds:
 * tabs, one scan box for both kinds of samples, samples from other labs,
 * the sent-transfer list and its actions, and the "new transfer" form.
 * Same server APIs as before; nothing here changes how data is stored. */
(function () {
    'use strict';

    const data = JSON.parse(document.getElementById('hubData').textContent || '{}');
    const copy = data.copy || {};
    const eligibleOrders = data.eligibleOrders || [];
    const $ = (id) => document.getElementById(id);
    const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
    const money = (n) => Number(n || 0).toLocaleString('en-US');
    const lang = document.documentElement.lang || 'ar';
    const dateText = (d) => (d ? new Date(d).toLocaleDateString(lang === 'ar' ? 'ar-IQ' : lang) : '');

    // ---------- toast (same look as the orders board) ----------
    function toast(message, type) {
        const box = $('toastContainer');
        if (!box || !message) return;
        const t = document.createElement('div');
        t.className = `la-toast ${type || 'info'}`;
        t.innerHTML = '<span class="dot"></span><span class="toast-message"></span>';
        t.querySelector('.toast-message').textContent = message;
        box.appendChild(t);
        setTimeout(() => { t.classList.add('removing'); setTimeout(() => t.remove(), 300); }, 4200);
    }

    // ---------- tabs ----------
    const tabs = [...document.querySelectorAll('#hubTabs [data-tab]')];
    const panes = [...document.querySelectorAll('.hub-pane')];
    function showTab(name, focus) {
        tabs.forEach((b) => { const on = b.dataset.tab === name; b.classList.toggle('on', on); b.setAttribute('aria-selected', String(on)); });
        panes.forEach((p) => { p.hidden = p.dataset.pane !== name; });
        const url = new URL(window.location.href);
        url.searchParams.set('tab', name);
        url.searchParams.delete('orderId');
        history.replaceState(null, '', url);
        if (focus && name === 'incoming') $('hubScanInput').focus();
    }
    tabs.forEach((b) => b.addEventListener('click', () => showTab(b.dataset.tab, true)));
    document.querySelectorAll('[data-go]').forEach((b) => b.addEventListener('click', () => showTab(b.dataset.go, true)));

    // ---------- counters ----------
    // Patient-order counts come from lab-orders.js (column badges); lab samples from here.
    const lab = { incoming: 0, inLab: 0 };
    function num(id) { return Number(($(id) && $(id).textContent) || 0) || 0; }
    function setCount(id, n) {
        const el = $(id);
        if (!el) return;
        el.textContent = n;
        if (el.classList.contains('hub-count')) el.hidden = !n;
    }
    function refreshCounters() {
        const incoming = num('incomingColumnCount') + lab.incoming;
        const inLab = num('inLabColumnCount') + lab.inLab;
        setCount('kpiIncoming', incoming);
        setCount('kpiInLab', inLab);
        setCount('tabCountIncoming', incoming);
        setCount('tabCountInLab', inLab);
    }
    ['incomingColumnCount', 'inLabColumnCount'].forEach((id) => {
        if ($(id)) new MutationObserver(refreshCounters).observe($(id), { childList: true, characterData: true, subtree: true });
    });

    // ---------- samples other LabGo labs sent here ----------
    function labCard(t) {
        const demo = [t.gender ? copy[t.gender] : '', t.age !== null && t.age !== undefined ? `${t.age} ${copy.years}` : ''].filter(Boolean).join(' · ');
        const base = `/lab/api/transfers/incoming/${t.id}`;
        const tags = (t.tests || []).slice(0, 6).map((n) => `<span class="la-tag"><svg class="ic"><use href="#i-test-tube"/></svg>${esc(n)}</span>`).join('');
        let pill = '';
        let actions = '';
        if (t.status === 'on_the_way') {
            pill = `<span class="la-pill amber">${esc(copy.onTheWay)}</span>`;
            actions = `<button type="button" class="la-btn md press-95" data-receive="${esc(t.code)}"><svg class="ic"><use href="#i-check"/></svg>${esc(copy.receive)}</button>`;
        } else if (t.status === 'received') {
            pill = `<span class="la-pill blue">${esc(copy.received)}</span>`;
            actions = `<a class="la-btn md press-95" href="/lab/transfers/incoming/${esc(t.id)}/results"><svg class="ic"><use href="#i-file-text"/></svg>${esc(copy.enterResults)}</a>`
                + `<button type="button" class="la-btn md soft press-95" data-upload="${esc(t.id)}" title="${esc(copy.uploadFile)}"><svg class="ic"><use href="#i-upload"/></svg>PDF</button>`;
        } else {
            pill = `<span class="la-pill green">${esc(copy.completed)}</span>`;
            actions = `<a class="la-btn md soft press-95" href="${esc(t.fileUrl || base + '/report.pdf')}" target="_blank" rel="noopener"><svg class="ic"><use href="#i-file-down"/></svg>${esc(copy.viewResult)}</a>`;
        }
        return `<div class="la-tile la-order hub-lab-card pop-in">
            <div class="la-order-top">
                <span class="la-avatar">${esc((t.patient || '?').trim().charAt(0).toUpperCase())}</span>
                <span class="main"><span class="name">${esc(t.patient)}</span><span class="meta">${esc(demo || copy.notAvailable)} · ${esc(t.code)}</span></span>
                ${pill}
            </div>
            <div class="hub-from"><svg class="ic"><use href="#i-building-2"/></svg>${esc(copy.fromLab)} <b>${esc(t.fromLab)}</b>${typeof t.price === 'number' ? `<span class="hub-price">${money(t.price)} ${esc(copy.currency)}</span>` : ''}</div>
            ${tags ? `<div class="la-tags">${tags}</div>` : ''}
            <div class="la-order-foot">
                <div class="la-meta-row"><span><svg class="ic"><use href="#i-clock"/></svg>${esc(dateText(t.sentAt))}</span></div>
                <div class="hub-actions">${actions}</div>
            </div>
        </div>`;
    }
    function emptyBox(icon, text) {
        return `<div class="la-empty-box"><svg class="ic"><use href="#i-${icon}"/></svg><p>${esc(text)}</p></div>`;
    }
    async function loadLabSamples() {
        try {
            const res = await fetch('/lab/api/transfers/incoming', { headers: { Accept: 'application/json' } });
            const body = await res.json();
            if (!body.success) throw new Error();
            const items = body.data.items || [];
            const onWay = items.filter((t) => t.status === 'on_the_way');
            const inLab = items.filter((t) => t.status !== 'on_the_way')
                .sort((a, b) => (a.status === 'completed') - (b.status === 'completed')); // open work first
            $('labIncomingList').innerHTML = onWay.length ? onWay.map(labCard).join('') : emptyBox('inbox', copy.noLabIncoming);
            $('labInLabList').innerHTML = inLab.length ? inLab.map(labCard).join('') : emptyBox('flask-conical', copy.noLabInLab);
            lab.incoming = onWay.length;
            lab.inLab = inLab.filter((t) => t.status === 'received').length;
            setCount('labIncomingCount', onWay.length);
            setCount('labInLabCount', inLab.length);
            refreshCounters();
        } catch (e) {
            ['labIncomingList', 'labInLabList'].forEach((id) => { if ($(id).querySelector('.la-spinner')) $(id).innerHTML = emptyBox('triangle-alert', copy.transferError); });
        }
    }

    async function receiveLabSample(code) {
        const res = await fetch('/lab/api/transfers/incoming/receive', {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ code }),
        });
        const body = await res.json().catch(() => ({}));
        if (!res.ok || !body.success) {
            const err = new Error(res.status === 404 ? copy.notFound : (body.message || copy.transferError));
            err.notFound = res.status === 404;
            throw err;
        }
        return body;
    }

    // ---------- one scan box: a patient order QR or another lab's tracking number ----------
    const looksLikeTracking = (code) => /^T[A-Z0-9]{6}$/i.test(code);
    async function receivePatientOrder(qrCode) {
        const res = await fetch('/lab/api/orders/scan-qr', {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ qrCode }),
        });
        const body = await res.json().catch(() => ({}));
        return { ok: res.ok && body.success, message: body.message, status: res.status };
    }
    $('hubScanForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const input = $('hubScanInput');
        const btn = $('hubScanBtn');
        const code = input.value.trim();
        if (!code) { input.focus(); return; }
        btn.disabled = true;
        try {
            if (looksLikeTracking(code)) {
                await receiveLabSample(code);
                toast(copy.receiveDone, 'success');
                showTab('inlab');
            } else {
                const r = await receivePatientOrder(code);
                if (r.ok) {
                    toast(copy.sampleReceived, 'success');
                    if (window.labOrders && window.labOrders.reload) window.labOrders.reload();
                } else {
                    // Not a patient order here: maybe a sample code from another lab.
                    try {
                        await receiveLabSample(code);
                        toast(copy.receiveDone, 'success');
                        showTab('inlab');
                    } catch (err) {
                        // Neither a patient order nor a sample sent here: one clear, translated message.
                        toast(err.notFound ? copy.notFound : err.message, 'error');
                        btn.disabled = false;
                        input.select();
                        return;
                    }
                }
            }
            input.value = '';
            loadLabSamples();
        } catch (err) {
            toast(err.message || copy.transferError, 'error');
            input.select();
        }
        btn.disabled = false;
    });

    // receive / upload from the lab-sample cards
    const incomingFile = $('incomingFile');
    let uploadFor = null;
    document.addEventListener('click', async (e) => {
        const r = e.target.closest('[data-receive]');
        if (r) {
            e.stopPropagation();
            r.disabled = true;
            try { await receiveLabSample(r.dataset.receive); toast(copy.receiveDone, 'success'); loadLabSamples(); }
            catch (err) { toast(err.message, 'error'); r.disabled = false; }
            return;
        }
        const u = e.target.closest('[data-upload]');
        if (u) { e.stopPropagation(); uploadFor = u.dataset.upload; incomingFile.value = ''; incomingFile.click(); }
    });
    incomingFile.addEventListener('change', async () => {
        const file = incomingFile.files[0];
        if (!file || !uploadFor) return;
        if (file.size > 5 * 1024 * 1024) { toast(copy.uploadError, 'error'); return; }
        const body = new FormData();
        body.append('resultFile', file);
        try {
            const res = await fetch(`/lab/api/transfers/incoming/${encodeURIComponent(uploadFor)}/upload-result?finish=1`, { method: 'POST', body });
            const d = await res.json();
            if (!res.ok || !d.success) throw new Error(d.message || copy.uploadError);
            toast(copy.resultDone, 'success');
            loadLabSamples();
        } catch (err) { toast(err.message || copy.uploadError, 'error'); }
    });

    // ---------- sent list: search + filter chips ----------
    let filter = 'all';
    function applyFilters() {
        const q = $('transferSearch').value.trim().toLowerCase();
        const rows = [...document.querySelectorAll('[data-transfer-row]')];
        let shown = 0;
        rows.forEach((row) => {
            const show = (!q || row.dataset.search.includes(q)) && (filter === 'all' || row.dataset.status === filter);
            row.hidden = !show;
            if (show) shown += 1;
        });
        $('emptySearch').classList.toggle('hidden', shown !== 0 || rows.length === 0);
    }
    $('transferSearch').addEventListener('input', applyFilters);
    document.querySelectorAll('#sentFilters [data-filter]').forEach((chip) => chip.addEventListener('click', () => {
        filter = chip.dataset.filter;
        document.querySelectorAll('#sentFilters [data-filter]').forEach((c) => c.classList.toggle('on', c === chip));
        applyFilters();
    }));

    // ---------- modals ----------
    const newTransferModal = $('newTransferModal');
    const resultModal = $('resultModal');
    let lastFocus = null;
    function setModal(modal, open) {
        if (open) lastFocus = document.activeElement;
        modal.classList.toggle('active', open);
        document.body.style.overflow = open ? 'hidden' : '';
        if (open) setTimeout(() => { const f = modal.querySelector('select, input:not([type=hidden]), button'); if (f) f.focus(); }, 60);
        else if (lastFocus) lastFocus.focus();
    }
    document.querySelectorAll('[data-close-modal]').forEach((b) => b.addEventListener('click', () => setModal(newTransferModal, false)));
    document.querySelectorAll('[data-close-result]').forEach((b) => b.addEventListener('click', () => setModal(resultModal, false)));
    document.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape') return;
        if (newTransferModal.classList.contains('active')) setModal(newTransferModal, false);
        if (resultModal.classList.contains('active')) setModal(resultModal, false);
    });

    // ---------- new transfer ----------
    let transferMode = 'order';
    const sampleSelect = $('sampleOrderId');
    function setTransferMode(mode) {
        transferMode = mode;
        document.querySelectorAll('#transferModeTabs [data-mode]').forEach((b) => b.classList.toggle('on', b.dataset.mode === mode));
        $('orderModeSection').hidden = mode !== 'order';
        $('manualModeSection').hidden = mode !== 'manual';
        if (mode === 'manual') { $('patientInfoCard').hidden = true; $('testSelectPanel').hidden = true; } else updateAutoFill();
        scheduleQuote();
    }
    document.querySelectorAll('#transferModeTabs [data-mode]').forEach((b) => b.addEventListener('click', () => setTransferMode(b.dataset.mode)));

    function updateAutoFill() {
        const order = eligibleOrders.find((o) => String(o._id) === sampleSelect.value);
        $('patientInfoCard').hidden = !order;
        $('testSelectPanel').hidden = !order;
        if (!order) return;
        const info = order.patientInfo || {};
        const loc = order.location || {};
        $('autoPatientInitial').textContent = (info.name || '?').trim().charAt(0).toUpperCase();
        $('autoPatientName').textContent = info.name || copy.notAvailable;
        $('autoPatientGender').textContent = info.gender && copy[info.gender] ? copy[info.gender] : copy.notAvailable;
        $('autoPatientAge').textContent = info.age !== null && info.age !== undefined ? `${info.age} ${copy.years}` : copy.notAvailable;
        $('autoPatientPhone').textContent = info.phone || copy.notAvailable;
        $('autoPatientAddress').textContent = [loc.address, loc.landmark].filter(Boolean).join(' - ');
        $('autoSampleCode').textContent = order.qrCode || '—';
        $('testSelectList').innerHTML = (order.tests || []).map((t) => `
            <label class="hub-test-item"><input type="checkbox" name="testIds" value="${esc(t.testId)}" checked><span>${esc(t.testName)}</span></label>`).join('');
    }
    sampleSelect.addEventListener('change', () => { updateAutoFill(); scheduleQuote(); });

    $('openTransferModal').addEventListener('click', () => {
        setModal(newTransferModal, true);
        setTransferMode(eligibleOrders.length ? 'order' : 'manual');
    });

    $('newTransferForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const btn = $('saveTransferButton');
        const values = Object.fromEntries(new FormData(e.currentTarget).entries());
        delete values.orderId;
        delete values.testIds;
        if (!priceEdited || !values.price) delete values.price;
        if (!values.toLabId) delete values.toLabId;
        if (transferMode === 'order') {
            if (!sampleSelect.value) { toast(copy.transferError, 'error'); sampleSelect.focus(); return; }
            values.orderId = sampleSelect.value;
            values.testIds = [...document.querySelectorAll('#testSelectList input:checked')].map((el) => el.value);
        } else {
            const patientName = $('manualPatientName').value.trim();
            if (!patientName) { toast(copy.patientNameRequired, 'error'); $('manualPatientName').focus(); return; }
            values.patientName = patientName;
            values.patientPhone = $('manualPatientPhone').value.trim();
            values.patientGender = $('manualPatientGender').value;
            values.patientAge = $('manualPatientAge').value;
            values.sampleCode = $('manualSampleCode').value.trim();
            values.testsDescription = $('manualTestsDescription').value.trim();
        }
        btn.disabled = true;
        try {
            const res = await fetch('/lab/api/external-transfers', {
                method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(values),
            });
            const d = await res.json();
            if (!res.ok || !d.success) throw new Error(d.message || copy.transferError);
            toast(copy.transferSaved, 'success');
            setTimeout(() => window.location.assign('/lab/orders?tab=sent'), 600);
        } catch (err) {
            toast(err.message || copy.transferError, 'error');
            btn.disabled = false;
        }
    });

    // registered (LabGo) receiving lab + price from its B2B prices
    const labSearch = $('labSearch');
    const labResults = $('labResults');
    const toLabId = $('toLabId');
    const priceInput = $('transferPrice');
    const priceHint = $('priceHint');
    let priceEdited = false;
    let labTimer = null;
    let quoteTimer = null;
    function chosenTestNames() {
        if (transferMode === 'order') return [...document.querySelectorAll('#testSelectList input:checked')].map((el) => el.nextElementSibling.textContent.trim());
        return $('manualTestsDescription').value.split(/[,،\n]/).map((x) => x.trim()).filter(Boolean);
    }
    async function refreshQuote() {
        priceHint.classList.remove('hub-warn');
        priceHint.textContent = copy.priceHint;
        if (!toLabId.value || priceEdited) return;
        const names = chosenTestNames();
        if (!names.length) { priceInput.value = ''; return; }
        try {
            const res = await fetch(`/lab/api/labs/${encodeURIComponent(toLabId.value)}/quote?tests=${encodeURIComponent(names.join(','))}`);
            const d = await res.json();
            if (!d.success) return;
            priceInput.value = d.data.lines.length ? money(d.data.total) : '';
            if (d.data.missing.length) {
                priceHint.classList.add('hub-warn');
                priceHint.textContent = `${copy.priceMissing}: ${d.data.missing.join(', ')} — ${copy.priceHint}`;
            }
        } catch (err) { /* the lab can still type the price */ }
    }
    function scheduleQuote() { clearTimeout(quoteTimer); quoteTimer = setTimeout(refreshQuote, 300); }
    function chooseLab(l) {
        toLabId.value = l ? l.id : '';
        $('labChosen').hidden = !l;
        labSearch.closest('.la-search').hidden = Boolean(l);
        labResults.hidden = true;
        if (l) {
            $('labChosenName').textContent = l.name + (l.city ? ` · ${l.city}` : '');
            $('externalLabName').value = l.name;
            if (l.phone) $('externalLabPhone').value = l.phone;
            if (l.address) $('externalLabAddress').value = l.address;
            priceEdited = false;
            refreshQuote();
        } else {
            labSearch.value = '';
            labSearch.focus();
        }
    }
    async function searchLabs() {
        try {
            const res = await fetch(`/lab/api/labs/directory?q=${encodeURIComponent(labSearch.value.trim())}`);
            const d = await res.json();
            const labs = (d.data && d.data.labs) || [];
            labResults.innerHTML = labs.length
                ? labs.map((l, i) => `<button type="button" data-i="${i}"><b>${esc(l.name)}</b><small>${esc([l.city, l.phone].filter(Boolean).join(' · '))}</small></button>`).join('')
                : `<p>${esc(copy.noLabs)}</p>`;
            labResults.querySelectorAll('button').forEach((b) => b.addEventListener('click', () => chooseLab(labs[Number(b.dataset.i)])));
            labResults.hidden = false;
        } catch (err) { labResults.hidden = true; }
    }
    labSearch.addEventListener('input', () => { clearTimeout(labTimer); labTimer = setTimeout(searchLabs, 250); });
    labSearch.addEventListener('focus', searchLabs);
    document.addEventListener('click', (e) => { if (!e.target.closest('.lab-picker')) labResults.hidden = true; });
    $('labClear').addEventListener('click', () => chooseLab(null));
    priceInput.addEventListener('input', () => {
        priceEdited = true;
        const digits = priceInput.value.replace(/[^0-9]/g, '');
        priceInput.value = digits ? money(digits) : '';
    });
    $('testSelectList').addEventListener('change', scheduleQuote);
    $('manualTestsDescription').addEventListener('input', scheduleQuote);

    // ---------- sent-card actions ----------
    let resultTransferId = null;
    const labelLang = data.labelLang || 'en';
    $('sentList').addEventListener('click', async (e) => {
        const btn = e.target.closest('[data-action]');
        if (!btn) return;
        const id = btn.dataset.transferId;
        const action = btn.dataset.action;
        if (action === 'upload-result') {
            resultTransferId = id;
            $('resultUploadForm').reset();
            $('selectedResultFile').textContent = 'PDF, JPG, PNG, HEIC, WEBP';
            setModal(resultModal, true);
        } else if (action === 'print-label') {
            window.open(`/lab/external-transfers/${encodeURIComponent(id)}/label?lang=${labelLang}`, '_blank');
        } else if (action === 'download-label') {
            btn.disabled = true;
            try {
                const res = await fetch(`/lab/api/external-transfers/${encodeURIComponent(id)}/label.pdf?lang=${labelLang}`);
                if (!res.ok) throw new Error(String(res.status));
                const url = URL.createObjectURL(await res.blob());
                const a = document.createElement('a');
                a.href = url;
                a.download = `label-${btn.dataset.code || 'sample'}.pdf`;
                document.body.appendChild(a);
                a.click();
                a.remove();
                setTimeout(() => URL.revokeObjectURL(url), 5000);
            } catch (err) {
                // No PDF engine on this server: open the printable label instead.
                window.open(`/lab/external-transfers/${encodeURIComponent(id)}/label?lang=${labelLang}`, '_blank');
            }
            btn.disabled = false;
        } else if (action === 'forward-result') {
            btn.disabled = true;
            try {
                const res = await fetch(`/lab/api/external-transfers/${encodeURIComponent(id)}/forward`, { method: 'POST' });
                const d = await res.json();
                if (!d.success) throw new Error(d.message);
                toast(copy.forwardDone, 'success');
                setTimeout(() => window.location.reload(), 800);
            } catch (err) { btn.disabled = false; toast(err.message || copy.transferError, 'error'); }
        } else if (action === 'delete-transfer') {
            if (!window.confirm(copy.confirmDeleteTransfer)) return;
            btn.disabled = true;
            try {
                const res = await fetch(`/lab/api/external-transfers/${encodeURIComponent(id)}`, { method: 'DELETE' });
                const d = await res.json();
                if (!res.ok || !d.success) throw new Error(d.message || copy.transferError);
                const card = btn.closest('[data-transfer-row]');
                card.classList.add('hub-leaving');
                setTimeout(() => { card.remove(); applyFilters(); if (!document.querySelector('[data-transfer-row]')) $('emptyTransfers').classList.remove('hidden'); }, 220);
            } catch (err) { btn.disabled = false; toast(err.message || copy.transferError, 'error'); }
        }
    });

    $('returnedResultFile').addEventListener('change', (e) => {
        const f = e.target.files[0];
        $('selectedResultFile').textContent = f ? f.name : 'PDF, JPG, PNG, HEIC, WEBP';
    });
    $('resultUploadForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        const file = $('returnedResultFile').files[0];
        if (!file || !resultTransferId) { $('returnedResultFile').click(); return; }
        if (file.size > 5 * 1024 * 1024) { toast(copy.uploadError, 'error'); return; }
        const btn = $('uploadResultButton');
        btn.disabled = true;
        try {
            const body = new FormData();
            body.append('resultFile', file);
            const res = await fetch(`/lab/api/external-transfers/${encodeURIComponent(resultTransferId)}/result`, { method: 'POST', body });
            const d = await res.json();
            if (!res.ok || !d.success) throw new Error(d.message || copy.uploadError);
            toast(copy.uploadSuccess, 'success');
            setTimeout(() => window.location.reload(), 800);
        } catch (err) { toast(err.message || copy.uploadError, 'error'); btn.disabled = false; }
    });

    // ---------- start ----------
    updateAutoFill();
    loadLabSamples();
    refreshCounters();
    if (data.selectedOrderId) {
        showTab('sent');
        setModal(newTransferModal, true);
        setTransferMode('order');
    }
})();
