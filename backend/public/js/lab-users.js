// Users & roles page.
(function () {
  'use strict';
  var data = JSON.parse(document.getElementById('usData').textContent);
  var S = JSON.parse(document.getElementById('usStrings').textContent);
  var $ = function (id) { return document.getElementById(id); };
  var toast = function (t) { if (window.laToast) window.laToast(t); };
  var COLORS = ['#FF5A00', '#007AFF', '#34C759', '#AF52DE', '#FF3B30', '#00C7BE', '#FF9500', '#8E8E93'];
  var editing = null, pickedRole = '';

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function roleName(r) { return (r && (r.name || S.roleNames[r.key])) || ''; }
  function roleOf(key) { return data.roles.find(function (r) { return r.key === key; }); }
  function initials(n) { return String(n || '?').trim().split(/\s+/).map(function (w) { return w[0]; }).slice(0, 2).join('').toUpperCase(); }
  function api(method, url, body) {
    return fetch(url, { method: method, headers: { 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined })
      .then(function (r) { return r.json().then(function (b) { if (!r.ok || !b.success) { var e = new Error(b.message); e.code = b.code; throw e; } return b; }); });
  }
  function errText(e) { return (e && e.code && S.errors[e.code]) || S.error; }

  // ---------- tabs ----------
  $('usTabs').addEventListener('click', function (e) {
    var b = e.target.closest('button[data-tab]');
    if (!b) return;
    this.querySelectorAll('button').forEach(function (x) { x.classList.toggle('on', x === b); });
    $('usUsers').hidden = b.dataset.tab !== 'users';
    $('usRoles').hidden = b.dataset.tab !== 'roles';
  });

  // ---------- users ----------
  function renderUsers() {
    $('usUserCount').textContent = '(' + data.staff.length + ')';
    var rows = [];
    if (data.owner && data.owner.name) {
      rows.push('<div class="us-user"><div class="us-avatar" style="background:var(--accent)">' + esc(initials(data.owner.name)) + '</div>' +
        '<div class="us-text"><b>' + esc(data.owner.name) + ' <span class="la-sub">(' + esc(S.you) + ')</span></b></div>' +
        '<span class="us-pill" style="background:var(--soft-accent);color:var(--accent)">' + esc(S.owner) + '</span></div>');
    }
    data.staff.forEach(function (u) {
      var r = roleOf(u.roleKey);
      var color = (r && r.color) || '#8E8E93';
      rows.push('<div class="us-user ' + (u.active ? '' : 'off') + '" data-id="' + u._id + '">' +
        '<div class="us-avatar" style="background:' + esc(color) + '">' + esc(initials(u.name)) + '</div>' +
        '<div class="us-text"><b>' + esc(u.name) + '</b><small>' + esc([u.phone, u.email].filter(Boolean).join(' · ')) + '</small></div>' +
        '<span class="us-pill" style="background:color-mix(in srgb,' + esc(color) + ' 14%, transparent);color:' + esc(color) + '">' + esc(roleName(r)) + '</span>' +
        '<div class="us-actions">' +
        '<button type="button" class="la-switch ' + (u.active ? 'on' : '') + '" data-act="toggle" role="switch" aria-checked="' + u.active + '" title="' + esc(u.active ? S.active : S.inactive) + '"></button>' +
        '<button type="button" class="us-icon" data-act="edit" aria-label="' + esc(S.editUser) + '"><svg class="ic"><use href="#i-pencil"/></svg></button>' +
        '<button type="button" class="us-icon danger" data-act="remove" aria-label="' + esc(S.remove) + '"><svg class="ic"><use href="#i-trash-2"/></svg></button>' +
        '</div></div>');
    });
    if (!data.staff.length) rows.push('<div class="us-empty"><svg class="ic"><use href="#i-users"/></svg>' + esc(S.noUsers) + '</div>');
    $('usUsers').innerHTML = rows.join('');
  }
  $('usUsers').addEventListener('click', function (e) {
    var b = e.target.closest('[data-act]');
    if (!b) return;
    var id = b.closest('[data-id]').dataset.id;
    var u = data.staff.find(function (x) { return x._id === id; });
    if (b.dataset.act === 'edit') return openModal(u);
    if (b.dataset.act === 'toggle') {
      api('PUT', '/lab/api/staff/' + id, { active: !u.active }).then(function (res) {
        Object.assign(u, res.data); renderUsers();
      }).catch(function (err) { toast(errText(err)); });
    }
    if (b.dataset.act === 'remove') {
      if (!window.confirm(S.confirmRemove.replace('{name}', u.name))) return;
      api('DELETE', '/lab/api/staff/' + id).then(function () {
        data.staff = data.staff.filter(function (x) { return x._id !== id; });
        renderUsers();
      }).catch(function (err) { toast(errText(err)); });
    }
  });

  // ---------- add / edit modal ----------
  var modal = $('usModal');
  function renderRolePick() {
    $('usRolePick').innerHTML = data.roles.map(function (r) {
      return '<button type="button" class="press-95 ' + (r.key === pickedRole ? 'on' : '') + '" data-key="' + esc(r.key) + '"><span class="us-dot" style="background:' + esc(r.color) + '"></span>' + esc(roleName(r)) + '</button>';
    }).join('');
  }
  $('usRolePick').addEventListener('click', function (e) {
    var b = e.target.closest('button[data-key]');
    if (!b) return;
    pickedRole = b.dataset.key;
    renderRolePick();
  });
  function openModal(u) {
    editing = u || null;
    $('usModalTitle').textContent = u ? S.editUser : S.addUser;
    $('usName').value = u ? u.name : '';
    $('usPhone').value = u ? u.phone : '';
    $('usEmail').value = u ? u.email : '';
    $('usPhone').disabled = $('usEmail').disabled = Boolean(u);
    $('usPassword').value = '';
    $('usPassLabel').textContent = u ? S.newPassword : S.password;
    pickedRole = u ? u.roleKey : 'technician';
    renderRolePick();
    $('usError').hidden = true;
    modal.classList.add('active');
    setTimeout(function () { $('usName').focus(); }, 50);
  }
  function closeModal() { modal.classList.remove('active'); }
  $('usAdd').addEventListener('click', function () { openModal(null); });
  modal.addEventListener('click', function (e) { if (e.target.closest('[data-close]')) closeModal(); });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeModal(); });
  $('usForm').addEventListener('submit', function (e) {
    e.preventDefault();
    var body = { name: $('usName').value.trim(), roleKey: pickedRole };
    var pass = $('usPassword').value;
    if (pass) body.password = pass;
    if (!editing) { body.phone = $('usPhone').value.trim(); body.email = $('usEmail').value.trim(); }
    var btn = $('usSubmit');
    btn.disabled = true;
    var req = editing ? api('PUT', '/lab/api/staff/' + editing._id, body) : api('POST', '/lab/api/staff', body);
    req.then(function (res) {
      if (editing) Object.assign(editing, res.data); else data.staff.unshift(res.data);
      renderUsers();
      closeModal();
      toast(S.saved);
    }).catch(function (err) {
      $('usError').textContent = errText(err);
      $('usError').hidden = false;
    }).finally(function () { btn.disabled = false; });
  });

  // ---------- roles ----------
  function renderRoles() {
    $('usRoleList').innerHTML = data.roles.map(function (r, i) {
      var locked = r.key === 'admin';
      return '<div class="us-role" data-i="' + i + '">' +
        '<div class="us-role-head"><span class="us-dot" style="background:' + esc(r.color) + '"></span>' +
        '<input class="us-role-name" value="' + esc(roleName(r)) + '" ' + (r.isDefault ? 'readonly' : '') + ' aria-label="' + esc(S.roleName) + '">' +
        (r.isDefault ? '' : '<button type="button" class="us-icon danger" data-del="' + i + '" aria-label="' + esc(S.remove) + '"><svg class="ic"><use href="#i-trash-2"/></svg></button>') +
        '</div><div class="us-perms">' +
        data.permissions.map(function (p) {
          var on = r.permissions.indexOf(p) !== -1;
          return '<div class="us-perm"><span>' + esc(S.perm[p] || p) + '</span><button type="button" class="la-switch ' + (on ? 'on' : '') + '" data-perm="' + p + '" role="switch" aria-checked="' + on + '"' + (locked ? ' disabled' : '') + '></button></div>';
        }).join('') + '</div></div>';
    }).join('');
  }
  $('usRoleList').addEventListener('click', function (e) {
    var card = e.target.closest('.us-role');
    if (!card) return;
    var r = data.roles[Number(card.dataset.i)];
    var sw = e.target.closest('[data-perm]');
    if (sw && !sw.disabled) {
      var p = sw.dataset.perm, idx = r.permissions.indexOf(p);
      if (idx === -1) r.permissions.push(p); else r.permissions.splice(idx, 1);
      sw.classList.toggle('on', idx === -1);
      sw.setAttribute('aria-checked', String(idx === -1));
    }
    var del = e.target.closest('[data-del]');
    if (del) { data.roles.splice(Number(del.dataset.del), 1); renderRoles(); }
  });
  $('usRoleList').addEventListener('input', function (e) {
    if (!e.target.matches('.us-role-name')) return;
    data.roles[Number(e.target.closest('.us-role').dataset.i)].name = e.target.value;
  });
  $('usAddRole').addEventListener('click', function () {
    var used = data.roles.map(function (r) { return r.color; });
    data.roles.push({ key: '', name: S.newRole, color: COLORS.find(function (c) { return used.indexOf(c) === -1; }) || COLORS[7], permissions: [], isDefault: false });
    renderRoles();
    var inputs = document.querySelectorAll('.us-role-name');
    var last = inputs[inputs.length - 1];
    last.focus(); last.select();
  });
  $('usSaveRoles').addEventListener('click', function () {
    var btn = this;
    btn.disabled = true;
    api('PUT', '/lab/api/staff/roles', { roles: data.roles.map(function (r) { return { key: r.key, name: r.isDefault ? (r.name || '') : r.name, color: r.color, permissions: r.permissions }; }) })
      .then(function (res) { data.roles = res.data.roles; renderRoles(); renderUsers(); toast(S.saved); })
      .catch(function (err) { toast(errText(err)); })
      .finally(function () { btn.disabled = false; });
  });

  renderUsers();
  renderRoles();
})();
