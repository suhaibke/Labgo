// Add patient (lab reception): phone autofill, test/package picker, totals, submit.
(function () {
  'use strict';
  var catalog = JSON.parse(document.getElementById('apCatalog').textContent);
  var S = JSON.parse(document.getElementById('apStrings').textContent);
  var ar = window.AP_LANG === 'ar' || window.AP_LANG === 'ku';
  var $ = function (id) { return document.getElementById(id); };
  var selTests = new Set(), selPkgs = new Set();
  var testById = {};
  catalog.tests.forEach(function (t) { testById[t._id] = t; });
  var DOCTORS_KEY = 'la-doctors';

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function money(n) { return Number(n || 0).toLocaleString('en-US') + ' ' + S.iqd; }
  function label(x) { return ar && x.nameAr ? x.nameAr : x.name; }
  function sub(x) { return ar && x.nameAr ? x.name : (x.nameAr || x.code || ''); }

  // ---------- segmented controls / chips ----------
  function single(groupId) {
    var g = $(groupId);
    g.addEventListener('click', function (e) {
      var b = e.target.closest('button[data-v]');
      if (!b) return;
      g.querySelectorAll('button').forEach(function (x) { x.classList.toggle('on', x === b); });
    });
    return function () { var on = g.querySelector('button.on'); return on ? on.dataset.v : ''; };
  }
  var ageUnit = single('apAgeUnit'), gender = single('apGender'), sample = single('apSample'), urgency = single('apUrgency');
  var payLater = false;
  $('apPayLater').addEventListener('click', function () {
    payLater = !payLater;
    this.classList.toggle('on', payLater);
    this.setAttribute('aria-checked', String(payLater));
  });

  // ---------- doctors remembered on this computer ----------
  function doctors() { try { return JSON.parse(localStorage.getItem(DOCTORS_KEY) || '[]'); } catch (e) { return []; } }
  $('apDoctors').innerHTML = doctors().map(function (d) { return '<option value="' + esc(d) + '">'; }).join('');

  // Name first, then Enter moves on to the phone.
  $('apName').addEventListener('keydown', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); $('apPhone').focus(); }
  });

  // ---------- phone autofill ----------
  var lookupTimer = null;
  $('apPhone').addEventListener('input', function () {
    clearTimeout(lookupTimer);
    $('apFound').hidden = true;
    var phone = this.value, n = phone.replace(/\D/g, '').length;
    // A phone (10+ digits) or a patient ID number (6-8 digits).
    var isId = n >= 6 && n <= 8 && /^#?\d+$/.test(phone.trim());
    if (n < 10 && !isId) return;
    lookupTimer = setTimeout(function () {
      fetch('/lab/api/patients/lookup?q=' + encodeURIComponent(phone)).then(function (r) { return r.json(); }).then(function (res) {
        var p = res && res.data;
        if (!p) return;
        if (isId && p.phone) $('apPhone').value = p.phone;
        $('apFoundNo').textContent = p.patientNo ? ' · #' + p.patientNo : '';
        $('apFound').hidden = false;
        if (!$('apName').value) $('apName').value = p.name || '';
        if (p.gender) $('apGender').querySelectorAll('button').forEach(function (b) { b.classList.toggle('on', b.dataset.v === p.gender); });
        if (p.birthDate && !$('apAge').value) {
          var years = Math.floor((Date.now() - new Date(p.birthDate)) / 31557600000);
          if (years >= 1) $('apAge').value = years;
        }
      }).catch(function () {});
    }, 400);
  });

  // ---------- picker ----------
  function pkgTestIds() {
    var ids = new Set();
    catalog.packages.forEach(function (p) { if (selPkgs.has(p._id)) p.testIds.forEach(function (id) { ids.add(id); }); });
    return ids;
  }
  function itemHtml(kind, x, on, price, extra) {
    return '<button type="button" class="ap-item press-95 ' + (kind === 'pkg' ? 'pkg ' : '') + (on ? 'on' : '') + '" data-kind="' + kind + '" data-id="' + x._id + '">' +
      '<span class="ap-tick"><svg class="ic"><use href="#i-check"/></svg></span>' +
      '<span class="ap-item-text">' + (kind === 'pkg' ? '<span class="ap-pkg-tag">' + esc(S.packageLabel) + '</span>' : '') +
      '<b>' + esc(label(x)) + '</b><small>' + esc(extra) + '</small></span>' +
      '<span class="ap-price" dir="ltr">' + esc(Number(price).toLocaleString('en-US')) + '</span></button>';
  }
  function renderPicker() {
    var q = $('apSearch').value.trim().toLowerCase();
    var match = function (x) { return !q || [x.name, x.nameAr, x.code].join(' ').toLowerCase().indexOf(q) !== -1; };
    var inPkg = pkgTestIds();
    $('apPackages').innerHTML = catalog.packages.filter(match).map(function (p) {
      return itemHtml('pkg', p, selPkgs.has(p._id), p.price, p.testIds.map(function (id) { return testById[id] ? label(testById[id]) : ''; }).join(' · '));
    }).join('');
    var tests = catalog.tests.filter(match);
    $('apTests').innerHTML = tests.length
      ? tests.map(function (t) { return itemHtml('test', t, selTests.has(t._id) || inPkg.has(t._id), t.price, sub(t)); }).join('')
      : '<div class="ap-empty">' + esc(catalog.tests.length ? S.noMatch : S.noTests) + '</div>';
  }
  function onPick(e) {
    var b = e.target.closest('.ap-item');
    if (!b) return;
    var set = b.dataset.kind === 'pkg' ? selPkgs : selTests;
    var id = b.dataset.id;
    if (b.dataset.kind === 'test' && pkgTestIds().has(id)) return; // already in a chosen package
    if (set.has(id)) set.delete(id); else set.add(id);
    renderPicker();
    renderTotals();
  }
  $('apPackages').addEventListener('click', onPick);
  $('apTests').addEventListener('click', onPick);
  $('apSearch').addEventListener('input', renderPicker);
  $('apSearch').addEventListener('keydown', function (e) {
    // Enter picks the first match: fast keyboard entry at the reception desk.
    if (e.key !== 'Enter') return;
    e.preventDefault();
    var first = document.querySelector('#apPackages .ap-item, #apTests .ap-item');
    if (first) { first.click(); this.select(); }
  });

  // ---------- totals ----------
  function lines() {
    var out = [], inPkg = pkgTestIds();
    catalog.packages.forEach(function (p) { if (selPkgs.has(p._id)) out.push({ kind: 'pkg', id: p._id, name: label(p), price: p.price }); });
    selTests.forEach(function (id) {
      if (inPkg.has(id) || !testById[id]) return;
      out.push({ kind: 'test', id: id, name: label(testById[id]), price: testById[id].price });
    });
    return out;
  }
  function renderTotals() {
    var l = lines();
    var subtotal = l.reduce(function (s, x) { return s + x.price; }, 0);
    var discount = Math.min(subtotal, Math.max(0, parseInt(String($('apDiscount').value).replace(/\D/g, ''), 10) || 0));
    $('apSelected').innerHTML = l.map(function (x) {
      return '<span class="ap-sel">' + esc(x.name) + '<button type="button" data-kind="' + x.kind + '" data-id="' + x.id + '" aria-label="' + esc(S.remove) + '"><svg class="ic"><use href="#i-x"/></svg></button></span>';
    }).join('');
    $('apSubtotal').textContent = money(subtotal);
    $('apTotal').textContent = money(subtotal - discount);
    var count = $('apCount');
    count.textContent = String(l.length);
    count.classList.toggle('on', l.length > 0);
  }
  $('apSelected').addEventListener('click', function (e) {
    var b = e.target.closest('button[data-id]');
    if (!b) return;
    (b.dataset.kind === 'pkg' ? selPkgs : selTests).delete(b.dataset.id);
    renderPicker();
    renderTotals();
  });
  $('apDiscount').addEventListener('input', renderTotals);

  // ---------- submit ----------
  function fail(msg, focusId) {
    $('apError').textContent = msg;
    $('apError').hidden = false;
    if (focusId) $(focusId).focus();
  }
  $('apForm').addEventListener('submit', function (e) {
    e.preventDefault();
    $('apError').hidden = true;
    var phone = $('apPhone').value.trim(), name = $('apName').value.trim();
    if (!name) return fail(S.needName, 'apName');
    if (phone.replace(/\D/g, '').length < 10) return fail(S.needPhone, 'apPhone');
    if (!lines().length) return fail(S.needTests, 'apSearch');

    var btn = $('apSubmit'), txt = btn.querySelector('span'), old = txt.textContent;
    btn.disabled = true;
    txt.textContent = S.saving;
    var doctor = $('apDoctor').value.trim();
    fetch('/lab/api/walk-in-orders', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        phone: phone, name: name, age: $('apAge').value.trim(), ageUnit: ageUnit(), gender: gender(),
        doctor: doctor, company: $('apCompany').value.trim(), sampleType: sample(), urgency: urgency(),
        notes: $('apNotes').value.trim(), testIds: Array.from(selTests), packageIds: Array.from(selPkgs),
        discount: $('apDiscount').value, payLater: payLater,
      }),
    }).then(function (r) { return r.json().then(function (b) { return { ok: r.ok, body: b }; }); }).then(function (res) {
      if (!res.ok || !res.body.success) throw new Error(res.body.message || S.error);
      if (doctor) {
        try {
          var list = doctors().filter(function (d) { return d !== doctor; });
          list.unshift(doctor);
          localStorage.setItem(DOCTORS_KEY, JSON.stringify(list.slice(0, 30)));
        } catch (err) { /* private mode */ }
      }
      var id = res.body.data.orderId;
      $('apDoneName').textContent = name;
      $('apDoneCode').textContent = res.body.data.orderNo || res.body.data.qrCode;
      $('apPrintReceipt').href = '/lab/orders/' + id + '/receipt';
      var no = res.body.data.patientNo;
      $('apDoneNo').textContent = no ? '#' + no : '';
      $('apDoneNoWrap').hidden = !no;
      $('apGoResults').href = '/lab/orders/' + id + '/results';
      $('apGoOrder').href = '/lab/orders/' + id;
      $('apForm').hidden = true;
      $('apDone').hidden = false;
      window.scrollTo({ top: 0, behavior: 'smooth' });
      $('apGoResults').focus();
    }).catch(function (err) {
      fail(err && err.message ? err.message : S.error);
    }).finally(function () {
      btn.disabled = false;
      txt.textContent = old;
    });
  });

  $('apAnother').addEventListener('click', function () {
    $('apForm').reset();
    selTests.clear();
    selPkgs.clear();
    $('apFound').hidden = true;
    renderPicker();
    renderTotals();
    $('apDone').hidden = true;
    $('apForm').hidden = false;
    $('apName').focus();
  });

  renderPicker();
  renderTotals();
  $('apName').focus();
})();
