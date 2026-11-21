// Add patient (lab reception): name + age + gender, phone + doctor, test search
// that shows tests only while typing, B2B (company) prices, totals, print on save.
(function () {
  'use strict';
  var catalog = JSON.parse(document.getElementById('apCatalog').textContent);
  var S = JSON.parse(document.getElementById('apStrings').textContent);
  var ar = window.AP_LANG === 'ar' || window.AP_LANG === 'ku';
  var $ = function (id) { return document.getElementById(id); };
  var selTests = [], selPkgs = []; // in the order they were added
  var testById = {}, pkgById = {};
  catalog.tests.forEach(function (t) { testById[t._id] = t; });
  catalog.packages.forEach(function (p) { pkgById[p._id] = p; });
  var DOCTORS_KEY = 'la-doctors', COMPANIES_KEY = 'la-companies', PRINT_KEY = 'la-print-on-save';
  var b2b = false, payLater = false, printOnSave = false;

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function num(n) { return Number(n || 0).toLocaleString('en-US'); }
  function money(n) { return num(n) + ' ' + S.iqd; }
  function label(x) { return ar && x.nameAr ? x.nameAr : x.name; }
  function norm(s) { return String(s || '').toLowerCase().trim(); }
  // Same rule as the server: a company pays the test's B2B price when the lab set one.
  function testPrice(t) { return b2b && t.priceB2B > 0 ? t.priceB2B : (t.price || 0); }
  function stored(key, fallback) { try { var v = localStorage.getItem(key); return v === null ? fallback : JSON.parse(v); } catch (e) { return fallback; } }
  function store(key, v) { try { localStorage.setItem(key, JSON.stringify(v)); } catch (e) { /* private mode */ } }

  // ---------- small segmented controls / chips ----------
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
  function switchBtn(id, get, set) {
    var b = $(id);
    function paint() { b.classList.toggle('on', get()); b.setAttribute('aria-checked', String(get())); }
    b.addEventListener('click', function () { set(!get()); paint(); });
    paint();
    return paint;
  }
  switchBtn('apPayLater', function () { return payLater; }, function (v) { payLater = v; });
  printOnSave = stored(PRINT_KEY, false) === true;
  switchBtn('apPrintOnSave', function () { return printOnSave; }, function (v) { printOnSave = v; store(PRINT_KEY, v); });

  // ---------- B2B: company prices ----------
  var paintB2b = switchBtn('apB2b', function () { return b2b; }, function (v) {
    b2b = v;
    $('apCompanyRow').hidden = !v;
    if (v) $('apCompany').focus();
    renderResults();
    renderSelected();
  });
  paintB2b();

  // ---------- remembered doctors and companies ----------
  function fillList(listId, key) { $(listId).innerHTML = stored(key, []).map(function (d) { return '<option value="' + esc(d) + '">'; }).join(''); }
  function remember(key, value) {
    if (!value) return;
    var list = stored(key, []).filter(function (d) { return d !== value; });
    list.unshift(value);
    store(key, list.slice(0, 30));
  }
  fillList('apDoctors', DOCTORS_KEY);
  fillList('apCompanies', COMPANIES_KEY);

  // Enter moves through the first row: name → age → phone.
  $('apName').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); $('apAge').focus(); } });
  $('apAge').addEventListener('input', function () { this.value = this.value.replace(/\D/g, '').slice(0, 3); });
  $('apAge').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); $('apPhone').focus(); } });

  // ---------- a known patient fills the form ----------
  function fillPatient(p, overwrite) {
    $('apFoundNo').textContent = p.patientNo ? ' · #' + p.patientNo : '';
    $('apFound').hidden = false;
    if (overwrite || !$('apName').value) $('apName').value = p.name || '';
    if (p.phone && (overwrite || !$('apPhone').value)) $('apPhone').value = p.phone;
    if (p.gender) $('apGender').querySelectorAll('button').forEach(function (b) { b.classList.toggle('on', b.dataset.v === p.gender); });
    if (p.birthDate && (overwrite || !$('apAge').value)) {
      var years = Math.floor((Date.now() - new Date(p.birthDate)) / 31557600000);
      if (years >= 1) {
        $('apAge').value = years;
        $('apAgeUnit').querySelectorAll('button').forEach(function (b) { b.classList.toggle('on', b.dataset.v === 'Y'); });
      }
    }
    receiptHeader();
  }

  // ---------- name: the lab's past patients as you type ----------
  var nameTimer = null, nameHits = [], nameActive = -1, nameSeq = 0;
  function closeNames() { $('apNameHits').hidden = true; $('apName').setAttribute('aria-expanded', 'false'); nameActive = -1; }
  function drawNames() {
    var box = $('apNameHits');
    if (!nameHits.length) return closeNames();
    box.innerHTML = nameHits.map(function (p, i) {
      var sub = [p.phone, p.patientNo ? '#' + p.patientNo : ''].filter(Boolean).join(' · ');
      return '<button type="button" role="option" class="ap-res' + (i === nameActive ? ' active' : '') + '" data-i="' + i + '">' +
        '<span class="ap-res-text"><b>' + esc(p.name) + '</b><small dir="ltr">' + esc(sub) + '</small></span></button>';
    }).join('');
    box.hidden = false;
    $('apName').setAttribute('aria-expanded', 'true');
  }
  function pickName(i) {
    var p = nameHits[i];
    if (!p) return;
    closeNames();
    fillPatient(p, true);
    $('apSearch').focus();
  }
  $('apName').addEventListener('input', function () {
    clearTimeout(nameTimer);
    var q = this.value.trim();
    if (q.length < 2) { nameHits = []; return closeNames(); }
    var seq = ++nameSeq;
    nameTimer = setTimeout(function () {
      fetch('/lab/api/patients/search?q=' + encodeURIComponent(q)).then(function (r) { return r.json(); }).then(function (res) {
        if (seq !== nameSeq) return;
        nameHits = (res && res.data) || [];
        nameActive = nameHits.length ? 0 : -1;
        drawNames();
      }).catch(function () {});
    }, 250);
  });
  $('apName').addEventListener('keydown', function (e) {
    if ($('apNameHits').hidden) return;
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      nameActive = (nameActive + (e.key === 'ArrowDown' ? 1 : -1) + nameHits.length) % nameHits.length;
      drawNames();
    } else if (e.key === 'Enter' && nameActive >= 0) {
      e.preventDefault(); e.stopImmediatePropagation();
      pickName(nameActive);
    } else if (e.key === 'Escape') {
      closeNames();
    }
  }, true);
  $('apName').addEventListener('blur', function () { setTimeout(closeNames, 120); });
  $('apNameHits').addEventListener('mousedown', function (e) { e.preventDefault(); });
  $('apNameHits').addEventListener('click', function (e) {
    var b = e.target.closest('.ap-res');
    if (b) pickName(Number(b.dataset.i));
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
        fillPatient(p, false);
      }).catch(function () {});
    }, 400);
  });
  $('apPhone').addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); $('apSearch').focus(); } });

  // ---------- tests: shown only while searching ----------
  function pkgTestIds() {
    var ids = {};
    selPkgs.forEach(function (id) { (pkgById[id] ? pkgById[id].testIds : []).forEach(function (t) { ids[t] = true; }); });
    return ids;
  }
  var results = [], active = 0;
  function renderResults() {
    var q = norm($('apSearch').value);
    var box = $('apResults');
    if (!q) { box.hidden = true; results = []; return; }
    var match = function (x) { return [x.name, x.nameAr, x.code].join(' ').toLowerCase().indexOf(q) !== -1; };
    var inPkg = pkgTestIds();
    results = catalog.packages.filter(match).slice(0, 3).map(function (p) { return { kind: 'pkg', x: p }; })
      .concat(catalog.tests.filter(match).slice(0, 8).map(function (t) { return { kind: 'test', x: t }; }));
    if (active >= results.length) active = 0;
    if (!results.length) {
      box.innerHTML = '<div class="ap-res-empty">' + esc(catalog.tests.length ? S.noMatch : S.noTests) + '</div>';
      box.hidden = false;
      return;
    }
    box.innerHTML = results.map(function (r, i) {
      var x = r.x, isPkg = r.kind === 'pkg';
      var on = isPkg ? selPkgs.indexOf(x._id) !== -1 : (selTests.indexOf(x._id) !== -1 || inPkg[x._id]);
      var price = isPkg ? x.price : testPrice(x);
      var b2bNote = !isPkg && b2b && x.priceB2B > 0 ? '<small class="ap-res-b2b">' + esc(S.b2bPrice) + '</small>' : '';
      var sub = isPkg
        ? x.testIds.map(function (id) { return testById[id] ? label(testById[id]) : ''; }).filter(Boolean).join(' · ')
        : (ar && x.nameAr ? x.name : x.code);
      return '<button type="button" role="option" class="ap-res' + (i === active ? ' active' : '') + (on ? ' on' : '') + '" data-i="' + i + '">' +
        '<span class="ap-res-text"><b>' + (isPkg ? '<span class="ap-pkg-tag">' + esc(S.packageLabel) + '</span>' : '') + esc(label(x)) + '</b><small>' + esc(sub) + '</small></span>' +
        '<span class="ap-res-price" dir="ltr">' + esc(num(price)) + b2bNote + '</span>' +
        (on ? '<svg class="ic ap-res-tick"><use href="#i-check"/></svg>' : '') + '</button>';
    }).join('');
    box.hidden = false;
  }
  function pick(r) {
    var id = r.x._id;
    if (r.kind === 'pkg') {
      var i = selPkgs.indexOf(id);
      if (i === -1) selPkgs.push(id); else selPkgs.splice(i, 1);
    } else {
      if (pkgTestIds()[id]) return; // already in a chosen package
      var j = selTests.indexOf(id);
      if (j === -1) selTests.push(id); else selTests.splice(j, 1);
    }
    $('apSearch').value = '';
    renderResults();
    renderSelected();
    $('apSearch').focus();
  }
  $('apSearch').addEventListener('input', function () { active = 0; renderResults(); });
  $('apSearch').addEventListener('focus', renderResults);
  $('apSearch').addEventListener('keydown', function (e) {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      if (!results.length) return;
      e.preventDefault();
      active = (active + (e.key === 'ArrowDown' ? 1 : -1) + results.length) % results.length;
      renderResults();
    } else if (e.key === 'Enter') {
      // Enter adds the highlighted match: fast keyboard entry at the reception desk.
      e.preventDefault();
      if (results[active]) pick(results[active]);
    } else if (e.key === 'Escape') {
      this.value = '';
      renderResults();
    }
  });
  $('apResults').addEventListener('mousedown', function (e) { e.preventDefault(); });
  $('apResults').addEventListener('click', function (e) {
    var b = e.target.closest('[data-i]');
    if (b) pick(results[Number(b.dataset.i)]);
  });
  document.addEventListener('click', function (e) { if (!e.target.closest('.ap-combo')) $('apResults').hidden = true; });

  // ---------- the receipt printer ----------
  var printer = $('apPrinter');
  var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  function setStage(stage) {
    printer.dataset.stage = stage;
    $('apStatusText').textContent = { idle: S.stIdle, processing: S.stProcessing, printing: S.stPrinting, complete: S.stComplete }[stage];
  }
  // Torn bottom edge: 40 teeth, 4px deep.
  (function tornEdge() {
    var teeth = 40, depth = 4, pts = [];
    for (var i = 0; i < teeth * 2; i++) {
      var x = 100 - ((i + 1) * 100) / (teeth * 2);
      pts.push(x.toFixed(2) + '% ' + (i % 2 === 0 ? '100%' : 'calc(100% - ' + depth + 'px)'));
    }
    $('apPaper').style.clipPath = 'polygon(0 0, 100% 0, 100% calc(100% - ' + depth + 'px), ' + pts.join(', ') + ')';
  })();
  function two(n) { return (n < 10 ? '0' : '') + n; }
  function receiptHeader() {
    var d = new Date();
    $('apRDate').textContent = d.getDate() + '/' + (d.getMonth() + 1) + '/' + d.getFullYear() + '  ' + two(d.getHours()) + ':' + two(d.getMinutes());
    $('apRName').textContent = $('apName').value.trim() || '—';
    var age = $('apAge').value.trim();
    var unit = $('apAgeUnit').querySelector('button.on');
    $('apRMeta').textContent = [$('apPhone').value.trim(), age ? age + ' ' + (unit ? unit.textContent.trim() : '') : ''].filter(Boolean).join(' · ');
  }
  ['apName', 'apPhone', 'apAge'].forEach(function (id) { $(id).addEventListener('input', receiptHeader); });
  $('apAgeUnit').addEventListener('click', function () { setTimeout(receiptHeader, 0); });

  // ---------- chosen tests and totals ----------
  function lines() {
    var out = [], inPkg = pkgTestIds();
    selPkgs.forEach(function (id) { var p = pkgById[id]; if (p) out.push({ kind: 'pkg', id: id, name: label(p), price: p.price }); });
    selTests.forEach(function (id) {
      var t = testById[id];
      if (!t || inPkg[id]) return;
      out.push({ kind: 'test', id: id, name: label(t), price: testPrice(t) });
    });
    return out;
  }
  function renderSelected() {
    var l = lines();
    $('apSelected').innerHTML = l.map(function (x) {
      return '<span class="ap-sel' + (x.kind === 'pkg' ? ' pkg' : '') + '"><span class="ap-sel-name">' + esc(x.name) + '</span><span class="ap-sel-price" dir="ltr">' + esc(num(x.price)) + '</span>' +
        '<button type="button" data-kind="' + x.kind + '" data-id="' + x.id + '" aria-label="' + esc(S.remove) + '"><svg class="ic"><use href="#i-x"/></svg></button></span>';
    }).join('');
    $('apNoTests').hidden = l.length > 0;
    var subtotal = l.reduce(function (s, x) { return s + x.price; }, 0);
    var discount = Math.min(subtotal, Math.max(0, parseInt(String($('apDiscount').value).replace(/\D/g, ''), 10) || 0));
    $('apSubtotal').textContent = money(subtotal);
    $('apTotal').textContent = money(subtotal - discount);
    // the paper: one line per test or package
    $('apRLines').innerHTML = l.length
      ? l.map(function (x) { return '<li><span>' + esc(x.name) + '</span><span>' + esc(num(x.price)) + '</span></li>'; }).join('')
      : '<li class="ap-r-empty">' + esc(S.noTestsYet) + '</li>';
    $('apRDiscRow').hidden = !discount;
    $('apRDisc').textContent = '-' + num(discount);
    $('apRTotal').textContent = money(subtotal - discount);
    $('apPrinterCount').textContent = String(l.length);
    receiptHeader();
    var count = $('apCount');
    count.textContent = String(l.length);
    count.classList.toggle('on', l.length > 0);
  }
  $('apSelected').addEventListener('click', function (e) {
    var b = e.target.closest('button[data-id]');
    if (!b) return;
    var list = b.dataset.kind === 'pkg' ? selPkgs : selTests;
    var i = list.indexOf(b.dataset.id);
    if (i !== -1) list.splice(i, 1);
    renderSelected();
    renderResults();
  });
  $('apDiscount').addEventListener('input', function () {
    var d = this.value.replace(/\D/g, '');
    this.value = d ? num(d) : '';
    renderSelected();
  });

  // ---------- save ----------
  function fail(msg, focusId) {
    $('apError').textContent = msg;
    $('apError').hidden = false;
    if (focusId) $(focusId).focus();
  }
  $('apForm').addEventListener('submit', function (e) {
    e.preventDefault();
    $('apError').hidden = true;
    var phone = $('apPhone').value.trim(), name = $('apName').value.trim();
    var company = b2b ? $('apCompany').value.trim() : '';
    if (!name) return fail(S.needName, 'apName');
    if (phone.replace(/\D/g, '').length < 10) return fail(S.needPhone, 'apPhone');
    if (!lines().length) return fail(S.needTests, 'apSearch');
    if (b2b && !company) return fail(S.needCompany, 'apCompany');

    var btn = $('apSubmit'), txt = btn.querySelector('span'), old = txt.textContent;
    btn.disabled = true;
    receiptHeader();
    setStage('processing');
    txt.textContent = S.saving;
    var doctor = $('apDoctor').value.trim();
    fetch('/lab/api/walk-in-orders', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        phone: phone, name: name, age: $('apAge').value.trim(), ageUnit: ageUnit(), gender: gender(),
        doctor: doctor, company: company, sampleType: sample(), urgency: urgency(),
        notes: $('apNotes').value.trim(), testIds: selTests.slice(), packageIds: selPkgs.slice(),
        discount: $('apDiscount').value.replace(/\D/g, ''), payLater: payLater,
      }),
    }).then(function (r) { return r.json().then(function (b) { return { ok: r.ok, body: b }; }); }).then(function (res) {
      if (!res.ok || !res.body.success) throw new Error(res.body.message || S.error);
      remember(DOCTORS_KEY, doctor);
      remember(COMPANIES_KEY, company);
      var id = res.body.data.orderId;
      var receiptUrl = '/lab/orders/' + id + '/receipt';
      setStage('printing');
      if (printOnSave) printHere(receiptUrl);
      return new Promise(function (done) { setTimeout(done, reduceMotion ? 0 : 1750); }).then(function () {
        setStage('complete');
        return new Promise(function (done) { setTimeout(done, reduceMotion ? 200 : 900); });
      }).then(function () { return { id: id, receiptUrl: receiptUrl, body: res.body }; });
    }).then(function (saved) {
      var id = saved.id, receiptUrl = saved.receiptUrl, res = { body: saved.body };
      $('apDoneName').textContent = name;
      $('apDoneCode').textContent = res.body.data.orderNo || res.body.data.qrCode;
      savedId = id;
      var no = res.body.data.patientNo;
      $('apDoneNo').textContent = no ? '#' + no : '';
      $('apDoneNoWrap').hidden = !no;
      $('apGoResults').href = '/lab/orders/' + id + '/results';
      $('apGoOrder').href = '/lab/orders/' + id;
      $('apBefore').hidden = true;
      $('apAfter').hidden = false;
      $('apForm').classList.add('ap-saved');
      $('apPrintReceipt').focus();
    }).catch(function (err) {
      setStage('idle');
      fail(err && err.message ? err.message : S.error);
    }).finally(function () {
      btn.disabled = false;
      txt.textContent = old;
    });
  });

  // ---------- printing in a hidden frame: no new page ----------
  var savedId = null, copies = 1;
  function printHere(url) {
    // The receipt and label pages print themselves when they load.
    $('apPrintFrame').src = url + (url.indexOf('?') < 0 ? '?' : '&') + 't=' + Date.now();
  }
  $('apPrintReceipt').addEventListener('click', function () {
    if (savedId) printHere('/lab/orders/' + savedId + '/receipt');
  });
  $('apPrintLabel').addEventListener('click', function () {
    if (savedId) printHere('/lab/orders/' + savedId + '/tube-label?copies=' + copies);
  });
  document.querySelector('.ap-copies').addEventListener('click', function (e) {
    var b = e.target.closest('button[data-d]');
    if (!b) return;
    copies = Math.min(10, Math.max(1, copies + Number(b.dataset.d)));
    $('apCopies').textContent = copies;
  });

  $('apAnother').addEventListener('click', function () {
    $('apForm').reset();
    selTests = [];
    selPkgs = [];
    b2b = false;
    $('apCompanyRow').hidden = true;
    paintB2b();
    $('apFound').hidden = true;
    renderResults();
    renderSelected();
    savedId = null;
    $('apAfter').hidden = true;
    $('apBefore').hidden = false;
    $('apForm').classList.remove('ap-saved');
    setStage('idle');
    fillList('apDoctors', DOCTORS_KEY);
    fillList('apCompanies', COMPANIES_KEY);
    $('apName').focus();
  });

  renderSelected();
  $('apName').focus();
})();
