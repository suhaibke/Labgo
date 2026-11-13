// Result entry page: live flags, autosave, keyboard flow, normal range editor,
// printable report and "approve & send" (PDF -> existing upload -> approve).
(function () {
  'use strict';
  var data = JSON.parse(document.getElementById('rsData').textContent);
  var S = JSON.parse(document.getElementById('rsStrings').textContent);
  var editable = window.RS_EDITABLE;
  var orderId = data.order._id;
  var API = '/lab/api';
  // Orders by default; incoming samples from other labs use their own path.
  var BASE = window.RS_BASE || (API + '/orders/' + orderId);
  var $ = function (id) { return document.getElementById(id); };
  var toast = function (t) { if (window.laToast) window.laToast(t); };

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function isNum(v) { return v !== null && v !== undefined && v !== ''; }
  function classify(value, min, max) {
    var t = String(value || '').trim();
    if (!t) return '';
    var v = Number(t);
    if (!isFinite(v)) return '';
    if (isNum(min) && v < min) return 'low';
    if (isNum(max) && v > max) return 'high';
    if (!isNum(min) && !isNum(max)) return '';
    return 'normal';
  }
  function rangeText(r) {
    if (r.normalText) return r.normalText;
    if (isNum(r.min) && isNum(r.max)) return r.min + ' - ' + r.max;
    if (isNum(r.min)) return '≥ ' + r.min;
    if (isNum(r.max)) return '≤ ' + r.max;
    return '';
  }
  function flagLabel(f) { return f === 'high' ? S.high : f === 'low' ? S.low : f === 'normal' ? S.normal : ''; }

  // ---------- rows ----------
  function renderRows() {
    $('rsRows').innerHTML = data.rows.map(function (r, i) {
      var rt = rangeText(r);
      var rangeHtml = rt
        ? '<span class="rs-range-text" dir="ltr">' + esc(rt) + '</span>'
        : (r.labTestId && editable ? '<button type="button" class="rs-set-range" data-range="' + i + '"><svg class="ic"><use href="#i-ruler"/></svg>' + esc(S.setRange) + '</button>' : '<span class="rs-range-text">—</span>');
      return '<div class="rs-row ' + (r.flag || '') + '" data-i="' + i + '">' +
        '<div class="rs-name">' + esc(r.testName) + (r.testNameAr ? '<small>' + esc(r.testNameAr) + '</small>' : '') + '</div>' +
        '<div class="rs-value"><input type="text" inputmode="decimal" autocomplete="off" data-i="' + i + '" value="' + esc(r.value) + '" placeholder="' + esc(S.valuePlaceholder) + '" aria-label="' + esc(r.testName) + '"' + (editable ? '' : ' disabled') + '>' +
        (r.unit ? '<span class="rs-unit" dir="ltr">' + esc(r.unit) + '</span>' : '') + '</div>' +
        '<div class="rs-range">' + rangeHtml +
        '<span class="rs-flag ' + (r.flag || '') + '"' + (r.flag ? '' : ' hidden') + '>' + esc(flagLabel(r.flag)) + '</span>' +
        (rt && r.labTestId && editable ? '<button type="button" class="rs-edit-range" data-range="' + i + '" title="' + esc(S.editRange) + '"><svg class="ic"><use href="#i-pencil"/></svg></button>' : '') +
        '</div></div>';
    }).join('');
    updateCount();
  }

  function updateRow(i) {
    var r = data.rows[i];
    var row = document.querySelector('.rs-row[data-i="' + i + '"]');
    r.flag = classify(r.value, r.min, r.max);
    row.classList.remove('high', 'low', 'normal');
    if (r.flag) row.classList.add(r.flag);
    var f = row.querySelector('.rs-flag');
    f.className = 'rs-flag ' + (r.flag || '');
    f.textContent = flagLabel(r.flag);
    f.hidden = !r.flag;
  }

  function updateCount() {
    var filled = data.rows.filter(function (r) { return String(r.value || '').trim(); }).length;
    var el = $('rsCount');
    el.textContent = filled + ' / ' + data.rows.length + ' ' + S.filled;
    el.classList.toggle('done', filled === data.rows.length && filled > 0);
    var btn = $('rsApprove');
    if (btn) btn.disabled = filled !== data.rows.length || filled === 0;
  }

  function setStatus(st) {
    var el = $('rsStatus');
    el.dataset.status = st;
    el.textContent = S[st] || S.none;
    var btn = $('rsApprove');
    if (btn) btn.querySelector('span').textContent = st === 'approved' ? S.resend : btn.dataset.label;
  }

  // ---------- autosave ----------
  var saveTimer = null, saving = null;
  function valuesPayload() {
    return {
      values: data.rows.map(function (r) { return { testId: r.testId, value: r.value }; }),
      comment: $('rsComment').value,
    };
  }
  function scheduleSave() {
    clearTimeout(saveTimer);
    $('rsSaved').textContent = S.saving;
    saveTimer = setTimeout(saveNow, 700);
  }
  function saveNow() {
    clearTimeout(saveTimer);
    saving = fetch(BASE + '/results', {
      method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(valuesPayload()),
    }).then(function (r) { return r.json(); }).then(function (res) {
      if (!res.success) throw new Error(res.message);
      $('rsSaved').textContent = S.saved;
      setStatus(res.data.order.results.entryStatus);
    }).catch(function () {
      $('rsSaved').textContent = S.saveError;
    });
    return saving;
  }

  // ---------- inputs + keyboard flow ----------
  var inputs = function () { return Array.prototype.slice.call(document.querySelectorAll('.rs-value input')); };
  $('rsRows').addEventListener('input', function (e) {
    if (!e.target.matches('input[data-i]')) return;
    var i = Number(e.target.dataset.i);
    data.rows[i].value = e.target.value;
    updateRow(i);
    updateCount();
    scheduleSave();
  });
  $('rsRows').addEventListener('keydown', function (e) {
    if (!e.target.matches('input[data-i]')) return;
    var list = inputs(), idx = list.indexOf(e.target);
    if (e.key === 'Enter' || e.key === 'ArrowDown') {
      e.preventDefault();
      if (idx < list.length - 1) list[idx + 1].focus(); else $('rsComment').focus();
    } else if (e.key === 'ArrowUp' && idx > 0) {
      e.preventDefault();
      list[idx - 1].focus();
    }
  });
  $('rsRows').addEventListener('focusin', function (e) { if (e.target.matches('input[data-i]')) e.target.select(); });
  $('rsComment').addEventListener('input', scheduleSave);

  // ---------- normal range editor ----------
  var modal = $('rangeModal'), editing = null;
  function rangeRowHtml(r) {
    r = r || { gender: 'Both', ageFrom: 0, ageTo: 120, ageUnit: 'Y', min: '', max: '' };
    var opt = function (v, label, cur) { return '<option value="' + v + '"' + (v === cur ? ' selected' : '') + '>' + esc(label) + '</option>'; };
    return '<div class="rs-range-row">' +
      '<select data-k="gender">' + opt('Both', S.both, r.gender) + opt('Male', S.male, r.gender) + opt('Female', S.female, r.gender) + '</select>' +
      '<input data-k="ageFrom" inputmode="numeric" value="' + esc(r.ageFrom) + '" placeholder="' + esc(S.from) + '" aria-label="' + esc(S.from) + '">' +
      '<input data-k="ageTo" inputmode="numeric" value="' + esc(r.ageTo) + '" placeholder="' + esc(S.to) + '" aria-label="' + esc(S.to) + '">' +
      '<select data-k="ageUnit">' + opt('Y', S.years, r.ageUnit) + opt('M', S.months, r.ageUnit) + opt('D', S.days, r.ageUnit) + '</select>' +
      '<input data-k="min" inputmode="decimal" value="' + esc(r.min == null ? '' : r.min) + '" placeholder="' + esc(S.min) + '" aria-label="' + esc(S.min) + '">' +
      '<input data-k="max" inputmode="decimal" value="' + esc(r.max == null ? '' : r.max) + '" placeholder="' + esc(S.max) + '" aria-label="' + esc(S.max) + '">' +
      '<button type="button" data-remove title="' + esc(S.remove) + '"><svg class="ic"><use href="#i-trash-2"/></svg></button></div>';
  }
  function openRange(i) {
    var r = data.rows[i];
    editing = r;
    $('rangeTest').textContent = r.testName;
    $('rgUnit').value = r.unit || '';
    $('rgText').value = r.normalText || '';
    // All saved age/gender groups of the test, or one empty row to start.
    $('rgRows').innerHTML = (r.ranges && r.ranges.length ? r.ranges : [null]).map(rangeRowHtml).join('');
    modal.classList.add('active');
    setTimeout(function () { $('rgUnit').focus(); }, 50);
  }
  function closeRange() { modal.classList.remove('active'); editing = null; }
  $('rsRows').addEventListener('click', function (e) {
    var b = e.target.closest('[data-range]');
    if (b) openRange(Number(b.dataset.range));
  });
  modal.addEventListener('click', function (e) {
    if (e.target.closest('[data-close]')) closeRange();
    var rm = e.target.closest('[data-remove]');
    if (rm) rm.parentElement.remove();
  });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && modal.classList.contains('active')) closeRange(); });
  $('rgAdd').addEventListener('click', function () { $('rgRows').insertAdjacentHTML('beforeend', rangeRowHtml()); });
  $('rgSave').addEventListener('click', function () {
    if (!editing) return;
    var ranges = Array.prototype.map.call(document.querySelectorAll('#rgRows .rs-range-row'), function (row) {
      var o = {};
      row.querySelectorAll('[data-k]').forEach(function (el) { o[el.dataset.k] = el.value; });
      return o;
    }).filter(function (o) { return o.min !== '' || o.max !== ''; });
    var btn = $('rgSave');
    btn.disabled = true;
    fetch(API + '/tests/' + editing.labTestId + '/reference', {
      method: 'PUT', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ unit: $('rgUnit').value, normalText: $('rgText').value, ranges: ranges }),
    }).then(function (r) { return r.json(); }).then(function (res) {
      if (!res.success) throw new Error(res.message);
      return saveNow().then(function () { return fetch(BASE + '/results'); });
    }).then(function (r) { return r.json(); }).then(function (res) {
      data = res.data;
      renderRows();
      closeRange();
      toast(S.rangeSaved);
    }).catch(function () { toast(S.saveError); })
      .finally(function () { btn.disabled = false; });
  });

  // ---------- report ----------
  function fillReport() {
    $('rpRows').innerHTML = data.rows.map(function (r) {
      var f = classify(r.value, r.min, r.max);
      return '<tr class="' + f + '"><td>' + esc(r.testName) + '</td><td class="v" dir="ltr">' + esc(r.value) + '</td><td dir="ltr">' + esc(r.unit) +
        '</td><td dir="ltr">' + esc(rangeText(r)) + '</td><td class="f">' + (f === 'high' ? 'H' : f === 'low' ? 'L' : '') + '</td></tr>';
    }).join('');
    $('rpComment').textContent = $('rsComment').value.trim();
    $('rpDate').textContent = new Date().toLocaleDateString(window.RS_LANG === 'ar' ? 'ar-IQ' : window.RS_LANG);
  }
  // Print / preview: the same PDF the patient gets (a DRAFT copy until approved).
  // If the server cannot build PDFs, fall back to the browser's print.
  $('rsPrint').addEventListener('click', function () {
    var win = window.open('', '_blank');
    saveNow().then(function () {
      return fetch(BASE + '/report.pdf');
    }).then(function (r) {
      if (!r.ok) throw new Error(String(r.status));
      return r.blob();
    }).then(function (blob) {
      var url = URL.createObjectURL(blob);
      if (win) win.location = url; else window.location = url;
    }).catch(function () {
      if (win) win.close();
      fillReport();
      window.print();
    });
  });

  async function reportPdf() {
    fillReport();
    var el = $('rsReport');
    var canvas = await window.html2canvas(el, { scale: 2, backgroundColor: '#ffffff', useCORS: true });
    var pdf = new window.jspdf.jsPDF({ unit: 'mm', format: 'a4' });
    var w = 210, h = canvas.height * w / canvas.width;
    pdf.addImage(canvas.toDataURL('image/jpeg', 0.92), 'JPEG', 0, 0, w, Math.min(h, 297));
    return pdf.output('blob');
  }

  var approveBtn = $('rsApprove');
  if (approveBtn) {
    approveBtn.dataset.label = approveBtn.querySelector('span').textContent;
    approveBtn.addEventListener('click', async function () {
      approveBtn.disabled = true;
      var label = approveBtn.querySelector('span');
      label.textContent = S.sending;
      try {
        await saveNow();
        var approve = function (body) {
          return fetch(BASE + '/results/approve', {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
          }).then(function (r) { return r.json(); });
        };
        // The server builds the report PDF itself.
        var res = await approve(valuesPayload());
        if (!res.success && res.code === 'pdfUnavailable') {
          // Fallback: build the PDF in the browser and send it with the approval.
          var blob = await reportPdf();
          var form = new FormData();
          form.append('resultFile', new File([blob], 'result-' + (data.order.qrCode || orderId) + '.pdf', { type: 'application/pdf' }));
          var up = await fetch(BASE + '/upload-result', { method: 'POST', body: form }).then(function (r) { return r.json(); });
          if (!up.success) throw new Error(up.message);
          var body = valuesPayload();
          body.reportUrl = up.data.fileUrl;
          res = await approve(body);
        }
        if (!res.success) throw new Error(res.missing ? S.missing : res.message);
        data = res.data;
        renderRows();
        setStatus('approved');
        toast(S.sent);
      } catch (err) {
        toast(err && err.message === S.missing ? S.missing : S.sendError);
        setStatus(data.order.results.entryStatus);
      } finally {
        updateCount();
      }
    });
  }

  // ---------- start ----------
  $('rsComment').value = data.order.results.comment || '';
  renderRows();
  setStatus(data.order.results.entryStatus);
  if (editable) {
    var first = inputs().find(function (i) { return !i.value; }) || inputs()[0];
    if (first) first.focus();
  }
})();
