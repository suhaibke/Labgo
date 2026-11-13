// Finance page: period switch, KPIs, chart, expense breakdown, expenses, unpaid orders.
(function () {
  'use strict';
  var data = JSON.parse(document.getElementById('fnData').textContent);
  var S = JSON.parse(document.getElementById('fnStrings').textContent);
  var $ = function (id) { return document.getElementById(id); };
  var toast = function (t) { if (window.laToast) window.laToast(t); };
  var chart = null;
  var CAT_ICON = { rent: 'building-2', salaries: 'users', reagents: 'flask-conical', electricity: 'zap', transport: 'truck', maintenance: 'settings', other: 'receipt' };

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function money(n) { return Number(n || 0).toLocaleString('en-US'); }
  function fmtDate(d) { return new Date(d).toLocaleDateString(window.FN_LANG === 'ar' ? 'ar-IQ' : window.FN_LANG); }
  function css(name) { return getComputedStyle(document.documentElement).getPropertyValue(name).trim(); }

  function labels() {
    var n = data.series.income.length;
    if (data.unit === 'month') return S.months.slice(0, n);
    if (data.unit === 'hour') return Array.from({ length: n }, function (_, i) { return i + ':00'; });
    return Array.from({ length: n }, function (_, i) { return String(i + 1); });
  }

  function render() {
    document.querySelectorAll('#fnPeriod button').forEach(function (b) { b.classList.toggle('on', b.dataset.v === data.period); });
    var t = data.totals;
    $('kIncome').textContent = money(t.income);
    $('kExpenses').textContent = money(t.expenses);
    $('kProfit').textContent = money(t.profit);
    $('kProfit').classList.toggle('neg', t.profit < 0);
    $('kDebts').textContent = money(t.debts);

    // breakdown
    var cats = Object.keys(data.byCategory).sort(function (a, b) { return data.byCategory[b] - data.byCategory[a]; });
    var max = cats.length ? data.byCategory[cats[0]] : 0;
    $('fnBreakdown').innerHTML = cats.length ? cats.map(function (c) {
      return '<div class="fn-bar-row"><span>' + esc(S.cats[c] || c) + '</span><div class="fn-bar"><i style="width:' + Math.max(4, Math.round(data.byCategory[c] / max * 100)) + '%"></i></div><b dir="ltr">' + money(data.byCategory[c]) + '</b></div>';
    }).join('') : '<div class="fn-empty">' + esc(S.noExpenses) + '</div>';

    // expenses
    $('fnExpenses').innerHTML = data.expenses.length ? data.expenses.map(function (e) {
      return '<div class="fn-item" data-id="' + e._id + '"><div class="fn-item-ic"><svg class="ic"><use href="#i-' + (CAT_ICON[e.category] || 'receipt') + '"/></svg></div>' +
        '<div class="fn-item-text"><b>' + esc(S.cats[e.category] || e.category) + '</b><small>' + esc(fmtDate(e.date)) + (e.note ? ' · ' + esc(e.note) : '') + '</small></div>' +
        '<span class="fn-amt neg" dir="ltr">-' + money(e.amount) + '</span>' +
        '<button type="button" class="fn-del" data-del="' + e._id + '" aria-label="' + esc(S.remove) + '"><svg class="ic"><use href="#i-trash-2"/></svg></button></div>';
    }).join('') : '<div class="fn-empty">' + esc(S.noExpenses) + '</div>';

    // unpaid walk-in orders
    $('fnDebts').innerHTML = data.debts.length ? data.debts.map(function (d) {
      return '<div class="fn-item"><div class="fn-item-ic"><svg class="ic"><use href="#i-user"/></svg></div>' +
        '<div class="fn-item-text"><b>' + esc(d.name) + '</b><small dir="ltr">' + esc([d.phone, d.qrCode].filter(Boolean).join(' · ')) + '</small></div>' +
        '<span class="fn-amt" dir="ltr">' + money(d.amount) + '</span>' +
        '<button type="button" class="la-btn sm press-95" data-paid="' + d._id + '"><svg class="ic"><use href="#i-check"/></svg>' + esc(S.markPaid) + '</button></div>';
    }).join('') : '<div class="fn-empty">' + esc(S.noDebts) + '</div>';

    drawChart();
  }

  function drawChart() {
    if (!window.Chart) return;
    var accent = css('--accent') || '#FF5A00', muted = css('--muted') || '#8A8A8E', line = css('--line') || '#E7E7E9', red = css('--red') || '#FF3B30';
    var cfg = {
      type: 'bar',
      data: {
        labels: labels(),
        datasets: [
          { label: S.income, data: data.series.income, backgroundColor: accent, borderRadius: 6, maxBarThickness: 18 },
          { label: S.expenses, data: data.series.expenses, backgroundColor: red + '66', borderRadius: 6, maxBarThickness: 18 },
        ],
      },
      options: {
        responsive: true, maintainAspectRatio: false, animation: { duration: 400 },
        plugins: { legend: { position: 'bottom', labels: { color: muted, usePointStyle: true, boxWidth: 8 } } },
        scales: {
          x: { grid: { display: false }, ticks: { color: muted, maxRotation: 0, autoSkip: true } },
          y: { grid: { color: line }, ticks: { color: muted, callback: function (v) { return v >= 1000 ? (v / 1000) + 'k' : v; } } },
        },
      },
    };
    if (chart) chart.destroy();
    chart = new window.Chart($('fnChart'), cfg);
  }

  function load(period) {
    fetch('/lab/api/finance?period=' + encodeURIComponent(period)).then(function (r) { return r.json(); }).then(function (res) {
      if (!res.success) throw new Error();
      data = res.data;
      render();
      try { history.replaceState(null, '', '?period=' + period); } catch (e) { /* ignore */ }
    }).catch(function () { toast(S.error); });
  }
  $('fnPeriod').addEventListener('click', function (e) {
    var b = e.target.closest('button[data-v]');
    if (b) load(b.dataset.v);
  });

  $('fnExpenses').addEventListener('click', function (e) {
    var b = e.target.closest('[data-del]');
    if (!b || !window.confirm(S.confirmRemove)) return;
    fetch('/lab/api/finance/expenses/' + b.dataset.del, { method: 'DELETE' }).then(function (r) { return r.json(); })
      .then(function (res) { if (!res.success) throw new Error(); load(data.period); })
      .catch(function () { toast(S.error); });
  });
  $('fnDebts').addEventListener('click', function (e) {
    var b = e.target.closest('[data-paid]');
    if (!b) return;
    b.disabled = true;
    fetch('/lab/api/finance/orders/' + b.dataset.paid + '/paid', { method: 'POST' }).then(function (r) { return r.json(); })
      .then(function (res) { if (!res.success) throw new Error(); toast(S.paid); load(data.period); })
      .catch(function () { b.disabled = false; toast(S.error); });
  });

  // ---------- add expense ----------
  var modal = $('fnModal');
  function close() { modal.classList.remove('active'); }
  $('fnAddExpense').addEventListener('click', function () {
    $('fnForm').reset();
    $('fnDate').value = new Date().toISOString().slice(0, 10);
    $('fnError').hidden = true;
    modal.classList.add('active');
    setTimeout(function () { $('fnAmount').focus(); }, 50);
  });
  modal.addEventListener('click', function (e) { if (e.target.closest('[data-close]')) close(); });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') close(); });
  $('fnCats').addEventListener('click', function (e) {
    var b = e.target.closest('button[data-v]');
    if (!b) return;
    this.querySelectorAll('button').forEach(function (x) { x.classList.toggle('on', x === b); });
  });
  $('fnAmount').addEventListener('input', function () {
    var digits = this.value.replace(/\D/g, '');
    this.value = digits ? Number(digits).toLocaleString('en-US') : '';
  });
  $('fnForm').addEventListener('submit', function (e) {
    e.preventDefault();
    var amount = Number($('fnAmount').value.replace(/\D/g, ''));
    if (!amount) { $('fnError').textContent = S.needAmount; $('fnError').hidden = false; return; }
    var cat = $('fnCats').querySelector('button.on');
    fetch('/lab/api/finance/expenses', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ category: cat ? cat.dataset.v : 'other', amount: amount, date: $('fnDate').value, note: $('fnNote').value }),
    }).then(function (r) { return r.json(); }).then(function (res) {
      if (!res.success) throw new Error();
      close();
      toast(S.saved);
      load(data.period);
    }).catch(function () { $('fnError').textContent = S.error; $('fnError').hidden = false; });
  });

  render();
  // Chart.js loads with defer; draw once it is there.
  if (!window.Chart) window.addEventListener('load', drawChart);
})();
