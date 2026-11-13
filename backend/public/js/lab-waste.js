// Medical waste page: KPIs, log with filter, new request, mark collected.
(function () {
  'use strict';
  var data = JSON.parse(document.getElementById('wsData').textContent);
  var S = JSON.parse(document.getElementById('wsStrings').textContent);
  var $ = function (id) { return document.getElementById(id); };
  var toast = function (t) { if (window.laToast) window.laToast(t); };
  var filter = 'all';
  var COLOR = { biohazard: '#FF3B30', sharps: '#FF9500', chemical: '#AF52DE', general: '#8E8E93' };
  var ICON = { biohazard: 'triangle-alert', sharps: 'test-tube', chemical: 'flask-conical', general: 'trash-2' };
  var COMPANIES_KEY = 'la-waste-companies';

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fmtDate(d) { return new Date(d).toLocaleDateString(window.WS_LANG === 'ar' ? 'ar-IQ' : window.WS_LANG); }
  function kg(n) { return Number(n || 0).toLocaleString('en-US', { maximumFractionDigits: 2 }) + ' ' + S.kg; }

  function render() {
    $('wsPending').textContent = data.totals.pending;
    $('wsMonth').textContent = kg(data.totals.monthKg);
    var types = Object.keys(data.totals.byType);
    var max = Math.max.apply(null, types.map(function (t) { return data.totals.byType[t]; }).concat([0]));
    $('wsTypes').innerHTML = types.length ? types.map(function (t) {
      return '<div class="ws-type-row"><span><span class="ws-dot ws-' + t + '"></span> ' + esc(S.types[t]) + '</span><div class="ws-bar"><i style="width:' + Math.max(4, Math.round(data.totals.byType[t] / max * 100)) + '%;background:' + COLOR[t] + '"></i></div><b dir="ltr">' + esc(kg(data.totals.byType[t])) + '</b></div>';
    }).join('') : '<div class="la-sub">' + esc(S.noneThisMonth) + '</div>';

    var items = data.items.filter(function (w) { return filter === 'all' || w.status === filter; });
    $('wsList').innerHTML = items.length ? items.map(function (w) {
      var pending = w.status === 'pending';
      return '<div class="ws-item"><div class="ws-item-ic" style="background:' + COLOR[w.type] + '"><svg class="ic"><use href="#i-' + ICON[w.type] + '"/></svg></div>' +
        '<div class="ws-item-text"><b>' + esc(S.types[w.type]) + (w.requestNo ? ' <span dir="ltr">#' + esc(w.requestNo) + '</span>' : '') + '</b><small>' + esc([fmtDate(w.pickupDate), w.notes].filter(Boolean).join(' · ')) + '</small></div>' +
        '<span class="ws-kg" dir="ltr">' + esc(kg(w.weightKg)) + '</span>' +
        '<span class="ws-status ' + w.status + '">' + esc(pending ? S.pending : S.collected) + '</span>' +
        // The report travels with the waste; collection is confirmed by LabGo.
        '<a class="la-btn sm press-95" target="_blank" rel="noopener" href="/lab/api/waste/' + w._id + '/report.pdf"><svg class="ic"><use href="#i-file-text"/></svg>PDF</a>' +
        (pending ? '<button type="button" class="ws-del" data-del="' + w._id + '" aria-label="' + esc(S.remove) + '"><svg class="ic"><use href="#i-trash-2"/></svg></button>' : '') +
        '</div>';
    }).join('') : '<div class="ws-empty"><svg class="ic"><use href="#i-truck"/></svg>' + esc(S.empty) + '</div>';
  }

  function reload() {
    return fetch('/lab/api/waste').then(function (r) { return r.json(); }).then(function (res) {
      if (!res.success) throw new Error();
      data = res.data;
      render();
    });
  }

  $('wsFilter').addEventListener('click', function (e) {
    var b = e.target.closest('button[data-v]');
    if (!b) return;
    filter = b.dataset.v;
    this.querySelectorAll('button').forEach(function (x) { x.classList.toggle('on', x === b); });
    render();
  });
  $('wsList').addEventListener('click', function (e) {
    var c = e.target.closest('[data-collect]'), d = e.target.closest('[data-del]');
    if (c) {
      c.disabled = true;
      fetch('/lab/api/waste/' + c.dataset.collect + '/collected', { method: 'PATCH' }).then(function (r) { return r.json(); })
        .then(function (res) { if (!res.success) throw new Error(); return reload(); })
        .catch(function () { c.disabled = false; toast(S.error); });
    }
    if (d && window.confirm(S.confirmRemove)) {
      fetch('/lab/api/waste/' + d.dataset.del, { method: 'DELETE' }).then(function (r) { return r.json(); })
        .then(function (res) { if (!res.success) throw new Error(); return reload(); })
        .catch(function () { toast(S.error); });
    }
  });

  // ---------- new request ----------
  var modal = $('wsModal');
  function companies() { try { return JSON.parse(localStorage.getItem(COMPANIES_KEY) || '[]'); } catch (e) { return []; } }
  function close() { modal.classList.remove('active'); }
  $('wsNew').addEventListener('click', function () {
    $('wsForm').reset();
    $('wsDate').value = new Date().toISOString().slice(0, 10);
    $('wsError').hidden = true;
    modal.classList.add('active');
    setTimeout(function () { $('wsWeight').focus(); }, 50);
  });
  modal.addEventListener('click', function (e) { if (e.target.closest('[data-close]')) close(); });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') close(); });
  $('wsTypePick').addEventListener('click', function (e) {
    var b = e.target.closest('button[data-v]');
    if (!b) return;
    this.querySelectorAll('button').forEach(function (x) { x.classList.toggle('on', x === b); });
  });
  $('wsForm').addEventListener('submit', function (e) {
    e.preventDefault();
    var weight = Number(String($('wsWeight').value).replace(',', '.'));
    if (!(weight > 0)) { $('wsError').textContent = S.needWeight; $('wsError').hidden = false; return; }
    var type = $('wsTypePick').querySelector('button.on').dataset.v;
    var company = '';
    fetch('/lab/api/waste', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: type, weightKg: weight, pickupDate: $('wsDate').value, company: company, notes: $('wsNotes').value }),
    }).then(function (r) { return r.json(); }).then(function (res) {
      if (!res.success) throw new Error();
      if (company) {
        try {
          var list = companies().filter(function (c) { return c !== company; });
          list.unshift(company);
          localStorage.setItem(COMPANIES_KEY, JSON.stringify(list.slice(0, 10)));
        } catch (err) { /* private mode */ }
      }
      close();
      toast(S.saved);
      return reload();
    }).catch(function () { $('wsError').textContent = S.error; $('wsError').hidden = false; });
  });

  render();
})();
