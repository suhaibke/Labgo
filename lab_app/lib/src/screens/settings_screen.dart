import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../catalog_data.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import 'add_screen.dart' show formatNumber;
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../report_pdf.dart';

// ---------------------------------------------------------------------------
// small shared pieces

List<Widget> _gap(List<Widget> items, double gap) => [
  for (var i = 0; i < items.length; i++) ...[
    if (i > 0) SizedBox(height: gap),
    items[i],
  ],
];

/// The LabGo website (privacy policy, terms of use).
const kSiteUrl = 'https://www.labgo-iq.com';

Widget _col(List<Widget> items, {double gap = 12}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: _gap(items, gap),
);

/// `w-11 h-6 rounded-full p-0.5` switch with a 20px white knob.
class Toggle extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;
  final Color? onColor;
  const Toggle({
    super.key,
    required this.value,
    required this.onTap,
    this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? (onColor ?? pal.accent) : const Color(0xFFD9D9DD),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          curve: const Cubic(0.4, 0, 0.2, 1),
          alignment: value
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                  spreadRadius: -1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Label + input (`text-[12px] font-bold text-[var(--muted)]` then `mt-1`).
class _Field extends StatefulWidget {
  final String label;
  final String initial;
  final String? hint;
  final ValueChanged<String> onChanged;
  final double fontSize;
  final double vPad;
  final double radius;
  final double labelSize;
  final bool ltr;
  final int lines;
  final TextInputType? keyboard;
  final bool labelMuted;

  const _Field({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    this.hint,
    this.fontSize = 15,
    this.vPad = 12,
    this.radius = 16,
    this.labelSize = 12,
    this.ltr = false,
    this.lines = 1,
    this.keyboard,
    this.labelMuted = true,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );

  @override
  void didUpdateWidget(covariant _Field old) {
    super.didUpdateWidget(old);
    if (widget.initial != _c.text && old.initial != widget.initial)
      _c.text = widget.initial;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: ts(
            context,
            widget.labelSize,
            weight: w700,
            color: widget.labelMuted ? pal.muted : null,
          ),
        ),
        const SizedBox(height: 4),
        BoxField(
          controller: _c,
          hint: widget.hint,
          onChanged: widget.onChanged,
          fontSize: widget.fontSize,
          vPad: widget.vPad,
          radius: widget.radius,
          ltr: widget.ltr,
          lines: widget.lines,
          keyboard: widget.keyboard,
        ),
      ],
    );
  }
}

/// Rounded pill button.
Widget _pill(
  BuildContext context,
  String label, {
  required VoidCallback onTap,
  Color? color,
  Color? textColor,
  Color? border,
  double vPad = 12,
  double fontSize = 16,
  String? icon,
  double iconSize = 15,
  bool shrink = false,
  double hPad = 16,
}) {
  final pal = context.pal;
  final fg = textColor ?? pal.ink;
  return Tap(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(
        vertical: vPad - (border != null ? 1 : 0),
        horizontal: shrink ? hPad : 0,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Row(
        mainAxisSize: shrink ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            LIcon(icon, size: iconSize, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: ts(context, fontSize, weight: w700, color: fg),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Expanded section body (`bg-[var(--card)] rounded-[28px] … p-4 mt-3 space-y-3 pop-in shadow-sm`).
Widget _sectionBody(List<Widget> children, {double gap = 12}) => Padding(
  padding: const EdgeInsets.only(top: 12),
  child: Entrance.pop(
    child: CardBox(child: _col(children, gap: gap)),
  ),
);

// ---------------------------------------------------------------------------

/// Settings tab (design: profile).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (app.wastePage) return const _WastePage();
    final pal = app.palette;
    final w = app.w, d = app.d;

    Widget rowButton({
      required String icon,
      required String label,
      required VoidCallback onTap,
      bool open = false,
    }) => Tap(
      onTap: onTap,
      child: CardBox(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pal.chipBg,
                shape: BoxShape.circle,
              ),
              child: LIcon(icon, size: 18, color: pal.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: ts(context, 16, weight: w700)),
            ),
            AnimatedRotation(
              turns: open ? (app.rtl ? -.25 : .25) : 0,
              duration: const Duration(milliseconds: 150),
              child: LIcon(
                'ChevronRight',
                size: 18,
                color: pal.muted,
                flipX: app.rtl,
              ),
            ),
          ],
        ),
      ),
    );

    final sections = <(String, String, String)>[
      ('settings', w('settings'), 'User'),
      ('usersRoles', app.t('title'), 'Users'),
      ('financial', w('financial'), 'TrendingUp'),
      ('tests', w('manageTests'), 'FlaskConical'),
      (
        'createOrder',
        app.tr(
          'انشاء طلبية / Create Order',
          'دروستکردنی داواکاری / Create Order',
          'Create Order / انشاء طلبية',
        ),
        'ShoppingBag',
      ),
      ('packages', d('packagesManage'), 'ShoppingBag'),
      ('about', d('aboutTitle'), 'Globe'),
      ('support', app.tr('الدعم والبلاغات', 'پشتگیری', 'Support'), 'MessageSquare'),
      ('reports', w('manageReports'), 'FileText'),
      ('labData', d('labData'), 'Building2'),
      ('color', w('changeColor'), 'Pencil'),
    ];

    // Server mode: only the sections this account may use (staff permissions).
    const needs = {'usersRoles': 'users', 'financial': 'finance', 'tests': 'tests', 'packages': 'packages', 'labData': 'settings', 'createOrder': 'patients'};
    sections.removeWhere((sct) => needs[sct.$1] != null && !app.can(needs[sct.$1]!));

    Widget? body(String id) {
      switch (id) {
        case 'settings':
          return const _GeneralSettings();
        case 'usersRoles':
          return const _UsersRoles();
        case 'financial':
          return const _Financial();
        case 'tests':
          return const _ManageTests();
        case 'createOrder':
          return const _CreateOrder();
        case 'packages':
          return const _Packages();
        case 'about':
          return const _About();
        case 'support':
          return const _Support();
        case 'reports':
          return const _Reports();
        case 'labData':
          return const LabDataCard();
        case 'color':
          return const _ColorPicker();
      }
      return null;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        112 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          CardBox(
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: pal.avatarBg,
                    shape: BoxShape.circle,
                  ),
                  child: app.userPhoto != null
                      ? Image.memory(app.userPhoto!, width: 64, height: 64, fit: BoxFit.cover)
                      : Text(
                          app.profileInitial,
                          style: ts(context, 22, weight: w700),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${app.doctorName} - ${app.labDisplayName}',
                        style: ts(context, 19, weight: w700, height: 1.25),
                      ),
                      Text(
                        app.userRole,
                        style: ts(context, 13, color: pal.muted),
                      ),
                      Text(
                        app.userPhone,
                        textDirection: TextDirection.ltr,
                        style: ts(context, 12, color: pal.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () =>
                      app.updateSettings(() => app.profileEditOpen = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: pal.chipBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LIcon('Pencil', size: 13, color: pal.ink),
                        const SizedBox(width: 4),
                        Text(w('edit'), style: ts(context, 12, weight: w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (app.profileEditOpen) const _EditProfile(),
          const SizedBox(height: 12),
          rowButton(
            icon: 'Trash2',
            label: w('wasteTitle'),
            onTap: () => app.updateSettings(() => app.wastePage = true),
          ),
          const SizedBox(height: 12),
          rowButton(
            icon: 'ShoppingBag',
            label:
                '${app.tr('طلباتي', 'داواکارییەکانم', 'My Orders')}${app.productOrders.isNotEmpty ? ' (${app.productOrders.length})' : ''}',
            onTap: () => app.toast(
              app.tr(
                'المتجر يأتي في الدفعة القادمة',
                'فرۆشگا لە بەشی داهاتوودا دێت',
                'The store arrives in the next batch',
              ),
            ),
          ),
          for (final s in sections) ...[
            const SizedBox(height: 12),
            rowButton(
              icon: s.$3,
              label: s.$2,
              open: app.openSection == s.$1,
              onTap: () => app.toggleSection(s.$1),
            ),
            if (app.openSection == s.$1) body(s.$1)!,
          ],
          const SizedBox(height: 12),
          Tap(
            onTap: () => app.showLogout(true),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: context.pal.accentGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: context.pal.accentShadow,
                    offset: Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const LIcon('LogOut', size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    w('logout'),
                    style: ts(context, 16, weight: w700, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit profile

class _EditProfile extends StatefulWidget {
  const _EditProfile();

  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late String name, phone, address, lab, role, avatar, password;

  @override
  void initState() {
    super.initState();
    final app = context.app;
    name = app.doctorName;
    phone = app.userPhone;
    address = app.userAddress;
    lab = app.labDisplayName;
    role = app.userRole;
    avatar = app.profileInitial;
    password = '';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final d = app.d, w = app.w;
    final shown = avatar.isNotEmpty
        ? avatar
        : initials(name.isNotEmpty ? name : app.doctorName);
    return _sectionBody([
      Text(d('editUserData'), style: ts(context, 16, weight: w700)),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: pal.chipBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: pal.avatarBg,
                shape: BoxShape.circle,
              ),
              child: app.userPhoto != null
                  ? Image.memory(app.userPhoto!, width: 80, height: 80, fit: BoxFit.cover)
                  : Text(shown, style: ts(context, 26, weight: w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.tr('صورة المستخدم', 'وێنەی بەکارهێنەر', 'User Image'),
                    style: ts(context, 14, weight: w700),
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 8),
                  _pill(
                    context,
                    app.tr('تغيير الصورة', 'گۆڕینی وێنە', 'Change Image'),
                    onTap: app.pickUserPhoto,
                    color: pal.accent,
                    textColor: Colors.white,
                    vPad: 8,
                    fontSize: 12,
                    shrink: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app.tr(
                      'اختر من الاستوديو',
                      'لە ستۆدیۆ هەڵبژێرە',
                      'Choose from Studio',
                    ),
                    style: ts(context, 11, color: pal.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _Field(
        label: d('userNameLabel'),
        initial: name,
        hint: 'Dr. Ahmed',
        onChanged: (v) => setState(() => name = v),
      ),
      _Field(
        label: d('phoneLabel'),
        initial: phone,
        ltr: true,
        onChanged: (v) => phone = v,
      ),
      _Field(
        label: app.tr('العنوان', 'ناونیشان', 'Address'),
        initial: address,
        hint: 'Mosul, Al-Majmoua St.',
        onChanged: (v) => address = v,
      ),
      _Field(
        label: d('labNameLabel'),
        initial: lab,
        hint: 'LabGo Mosul',
        onChanged: (v) => lab = v,
      ),
      _Field(
        label: d('userRoleLabel'),
        initial: role,
        hint: w('labManager'),
        onChanged: (v) => role = v,
      ),
      _Field(
        label: d('passwordLabel'),
        initial: '',
        hint: '••••••••',
        onChanged: (v) => password = v,
      ),
      Row(
        children: [
          Expanded(
            child: _pill(
              context,
              w('cancel'),
              color: pal.segmented,
              onTap: () =>
                  app.updateSettings(() => app.profileEditOpen = false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _pill(
              context,
              d('saveChanges'),
              color: pal.accent,
              textColor: Colors.white,
              onTap: () {
                if (name.trim().isEmpty) return;
                app.updateSettings(() {
                  app.doctorName = name.trim();
                  app.userPhone = phone.trim().isNotEmpty
                      ? phone.trim()
                      : app.userPhone;
                  app.labDisplayName = lab.trim().isNotEmpty
                      ? lab.trim()
                      : app.labDisplayName;
                  app.userRole = role.trim().isNotEmpty
                      ? role.trim()
                      : app.userRole;
                  app.profileInitial = avatar.trim().isNotEmpty
                      ? avatar.trim()[0].toUpperCase()
                      : app.profileInitial;
                  if (address.trim().isNotEmpty)
                    app.userAddress = address.trim();
                  app.profileEditOpen = false;
                });
                app.toast(w('saved'));
              },
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _pill(
          context,
          d('deleteAccount'),
          color: Fixed.red,
          textColor: Colors.white,
          onTap: () => app.updateSettings(() => app.deleteAccountOpen = true),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// General settings

class _GeneralSettings extends StatelessWidget {
  const _GeneralSettings();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final w = app.w;
    Widget row(String label, Widget trailing) => Row(
      children: [
        Expanded(
          child: Text(label, style: ts(context, 14, weight: w700)),
        ),
        trailing,
      ],
    );
    return _sectionBody([
      row(
        w('language'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: pal.segmented,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final l in const [
                ('en', 'EN'),
                ('ar', 'عربي'),
                ('ku', 'کوردی'),
              ])
                GestureDetector(
                  onTap: () => app.updateSettings(() => app.lang = l.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: app.lang == l.$1 ? pal.ink : null,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l.$2,
                      style: ts(
                        context,
                        11,
                        weight: w700,
                        color: app.lang == l.$1
                            ? (pal.dark ? const Color(0xFF0B0B0D) : pal.appBg)
                            : pal.muted2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      row(
        w('theme'),
        GestureDetector(
          onTap: app.toggleTheme,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: pal.segmented,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              app.darkMode ? w('dark') : w('light'),
              style: ts(context, 12, weight: w700),
            ),
          ),
        ),
      ),
      row(
        w('notifs'),
        Toggle(
          value: app.notificationsOn,
          onTap: () => app.updateSettings(
            () => app.notificationsOn = !app.notificationsOn,
          ),
        ),
      ),
      GestureDetector(
        onTap: () => app.toast(w('passChanged')),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(w('changePass'), style: ts(context, 14, weight: w700)),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Users & roles

class _UsersRoles extends StatefulWidget {
  const _UsersRoles();

  @override
  State<_UsersRoles> createState() => _UsersRolesState();
}

class _UsersRolesState extends State<_UsersRoles> {
  String search = '';
  // user form
  bool userFormOpen = false;
  ManagedUser? editingUser;
  String uName = '', uPhone = '', uEmail = '', uPass = '', uRole = '';
  bool uActive = true;
  ManagedUser? deletingUser;
  int formVersion = 0;
  // role form
  bool roleFormOpen = false;
  LabRole? editingRole;
  String rName = '', rDesc = '';
  int rColor = 0xFFFF5A00;
  List<String> rPerms = [];
  LabRole? deletingRole;

  void _openUser([ManagedUser? u]) {
    final app = context.app;
    setState(() {
      editingUser = u;
      uName = u?.name ?? '';
      uPhone = u?.phone ?? '';
      uEmail = u?.email ?? '';
      uPass = '';
      uRole =
          u?.roleId ??
          (app.roles.isNotEmpty ? app.roles.first.id : 'role-receptionist');
      uActive = u?.active ?? true;
      userFormOpen = true;
      formVersion++;
    });
  }

  void _openRole([LabRole? r]) {
    final app = context.app;
    setState(() {
      editingRole = r;
      rName = r != null ? app.roleName(r) : '';
      rDesc = r != null ? app.roleDesc(r) : '';
      rColor = r?.color ?? 0xFFFF5A00;
      rPerms = r != null ? List.of(r.permissions) : [];
      roleFormOpen = true;
      formVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final t = app.t;
    final q = search.trim().toLowerCase();
    final shownUsers = app.users.where((u) {
      if (q.isEmpty) return true;
      final role = app.roles.where((r) => r.id == u.roleId);
      return u.name.toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (role.isNotEmpty &&
              app.roleName(role.first).toLowerCase().contains(q));
    }).toList();

    Widget subCard(List<Widget> children, {double gap = 12, Key? key}) =>
        Entrance.pop(
          key: key,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pal.chipBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pal.cardBorder),
            ),
            child: _col(children, gap: gap),
          ),
        );

    Widget confirmCard(
      String title,
      String desc,
      VoidCallback onCancel,
      VoidCallback onConfirm,
    ) => subCard([
      Text(title, style: ts(context, 15, weight: w700)),
      Text(desc, style: ts(context, 13, color: pal.muted)),
      Row(
        children: [
          Expanded(
            child: _pill(
              context,
              t('cancel'),
              color: pal.segmented,
              onTap: onCancel,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _pill(
              context,
              t('confirm'),
              color: Fixed.red,
              textColor: Colors.white,
              onTap: onConfirm,
            ),
          ),
        ],
      ),
    ], gap: 4);

    final tabs = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pal.segmented,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final tab in [('users', t('users')), ('roles', t('roles'))])
            Expanded(
              child: GestureDetector(
                onTap: () => app.updateSettings(() => app.usersTab = tab.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: app.usersTab == tab.$1 ? pal.ink : null,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tab.$2,
                    style: ts(
                      context,
                      13,
                      weight: w700,
                      color: app.usersTab == tab.$1
                          ? (pal.dark ? const Color(0xFF0B0B0D) : pal.appBg)
                          : pal.muted2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (app.usersTab == 'users') {
      return _sectionBody([
        tabs,
        Row(
          children: [
            Expanded(
              child: SearchBarBox(
                hint: t('searchUsers'),
                onChanged: (v) => setState(() => search = v),
              ),
            ),
            const SizedBox(width: 8),
            _pill(
              context,
              t('addUser'),
              onTap: _openUser,
              color: pal.accent,
              textColor: Colors.white,
              vPad: 10,
              fontSize: 13,
              icon: 'Plus',
              shrink: true,
            ),
          ],
        ),
        if (userFormOpen)
          subCard(key: ValueKey('uf-$formVersion'), <Widget>[
            Text(
              editingUser != null ? t('editUser') : t('addUser'),
              style: ts(context, 15, weight: w700),
            ),
            _Field(
              label: t('name'),
              initial: uName,
              hint: 'Dr. Ahmed',
              fontSize: 14,
              onChanged: (v) => uName = v,
            ),
            _Field(
              label: t('phone'),
              initial: uPhone,
              hint: '+964 770 000 0000',
              fontSize: 14,
              ltr: true,
              onChanged: (v) => uPhone = v,
            ),
            _Field(
              label: t('email'),
              initial: uEmail,
              hint: 'name@labgo.iq',
              fontSize: 14,
              ltr: true,
              onChanged: (v) => uEmail = v,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Field(
                  label: t('password'),
                  initial: '',
                  hint: '••••••••',
                  fontSize: 14,
                  onChanged: (v) => uPass = v,
                ),
                if (editingUser != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      t('newPasswordHint'),
                      style: ts(context, 11, color: pal.muted),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t('role'),
                  style: ts(context, 12, weight: w700, color: pal.muted),
                ),
                const SizedBox(height: 4),
                _SelectBox(
                  value: uRole,
                  options: [for (final r in app.roles) (r.id, app.roleName(r))],
                  onChanged: (v) => setState(() => uRole = v),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('activeLabel'),
                    style: ts(context, 13, weight: w700),
                  ),
                ),
                Toggle(
                  value: uActive,
                  onTap: () => setState(() => uActive = !uActive),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _pill(
                    context,
                    t('cancel'),
                    color: pal.segmented,
                    onTap: () => setState(() {
                      userFormOpen = false;
                      editingUser = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pill(
                    context,
                    t('save'),
                    color: pal.accent,
                    textColor: Colors.white,
                    onTap: () {
                      if (uName.trim().isEmpty) {
                        app.toast(t('fillName'));
                        return;
                      }
                      app.saveUser(
                        ManagedUser(
                          id:
                              editingUser?.id ??
                              '${DateTime.now().microsecondsSinceEpoch}',
                          name: uName.trim(),
                          phone: uPhone.trim(),
                          email: uEmail.trim(),
                          password: uPass.isNotEmpty
                              ? uPass
                              : (editingUser?.password ?? ''),
                          roleId: uRole,
                          active: uActive,
                        ),
                      );
                      setState(() {
                        userFormOpen = false;
                        editingUser = null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ]),
        if (deletingUser != null)
          confirmCard(
            t('confirmDelete'),
            '${deletingUser!.name} • ${t('deleteDesc')}',
            () => setState(() => deletingUser = null),
            () {
              app.deleteUser(deletingUser!);
              setState(() => deletingUser = null);
            },
          ),
        _col([
          for (final u in shownUsers)
            () {
              final roleMatch = app.roles.where((r) => r.id == u.roleId);
              final role = roleMatch.isNotEmpty ? roleMatch.first : null;
              final c = Color(role?.color ?? 0xFF8A8A8E);
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.chipBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pal.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: .1),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            initials(u.name),
                            style: ts(context, 15, weight: w900, color: c),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ts(context, 15, weight: w700),
                              ),
                              Text(
                                u.phone,
                                textDirection: TextDirection.ltr,
                                style: ts(context, 12, color: pal.muted),
                              ),
                              if (u.email.isNotEmpty)
                                Text(
                                  u.email,
                                  textDirection: TextDirection.ltr,
                                  style: ts(context, 11, color: pal.muted),
                                ),
                            ],
                          ),
                        ),
                        Toggle(
                          value: u.active,
                          onColor: Fixed.green,
                          onTap: () => app.toggleUserActive(u),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CssFlexWrap(
                      growIndex: 2,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            role != null ? app.roleName(role) : t('selectRole'),
                            style: ts(context, 11, weight: w700, color: c),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: u.active ? pal.softGreen : pal.segmented,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            u.active ? t('activeStatus') : t('inactive'),
                            style: ts(
                              context,
                              11,
                              weight: w700,
                              color: u.active ? pal.greenText : pal.muted2,
                            ),
                          ),
                        ),
                        const SizedBox.shrink(),
                        _pill(
                          context,
                          t('edit'),
                          onTap: () => _openUser(u),
                          color: pal.card,
                          border: pal.cardBorder,
                          vPad: 8,
                          fontSize: 12,
                          icon: 'Pencil',
                          iconSize: 13,
                          shrink: true,
                          hPad: 12,
                        ),
                        _pill(
                          context,
                          t('delete'),
                          onTap: () => setState(() => deletingUser = u),
                          color: Fixed.red,
                          textColor: Colors.white,
                          vPad: 8,
                          fontSize: 12,
                          icon: 'Trash2',
                          iconSize: 13,
                          shrink: true,
                          hPad: 12,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }(),
        ], gap: 8),
        if (shownUsers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              t('noUsers'),
              textAlign: TextAlign.center,
              style: ts(context, 13, color: pal.muted),
            ),
          ),
      ]);
    }

    // roles tab
    String perm((String, String, String, String) p) => app.lang == 'ar'
        ? p.$3
        : app.lang == 'ku'
        ? p.$4
        : p.$2;
    return _sectionBody([
      tabs,
      _pill(
        context,
        t('addRole'),
        onTap: _openRole,
        color: pal.accent,
        textColor: Colors.white,
        fontSize: 13,
        icon: 'Plus',
      ),
      if (roleFormOpen)
        subCard(key: ValueKey('rf-$formVersion'), [
          Text(
            editingRole != null ? t('editRole') : t('addRole'),
            style: ts(context, 15, weight: w700),
          ),
          _Field(
            label: t('name'),
            initial: rName,
            hint: app.tr(
              'مثال: مشرف مختبر',
              'بۆ نموونە: سەرپەرشتیار',
              'e.g. Lab Supervisor',
            ),
            fontSize: 14,
            onChanged: (v) => rName = v,
          ),
          _Field(
            label: app.tr('الوصف', 'وەسف', 'Description'),
            initial: rDesc,
            hint: app.tr('وصف الدور', 'وەسفی ڕۆڵ', 'Role description'),
            fontSize: 14,
            onChanged: (v) => rDesc = v,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.tr('لون الدور', 'ڕەنگی ڕۆڵ', 'Role color'),
                style: ts(context, 12, weight: w700, color: pal.muted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final c in const [
                    0xFFFF5A00,
                    0xFF007AFF,
                    0xFF34C759,
                    0xFFAF52DE,
                    0xFF8A8A8E,
                  ]) ...[
                    GestureDetector(
                      onTap: () => setState(() => rColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          boxShadow: rColor == c
                              ? [
                                  BoxShadow(color: pal.card, spreadRadius: 2),
                                  BoxShadow(color: pal.ink, spreadRadius: 4),
                                ]
                              : null,
                        ),
                        child: rColor == c
                            ? const LIcon(
                                'Check',
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('permissions'),
                style: ts(context, 12, weight: w700, color: pal.muted),
              ),
              const SizedBox(height: 8),
              ..._gap([
                for (final p in kPermissions)
                  GestureDetector(
                    onTap: () => setState(
                      () => rPerms.contains(p.$1)
                          ? rPerms.remove(p.$1)
                          : rPerms.add(p.$1),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: pal.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: rPerms.contains(p.$1)
                                  ? pal.accent
                                  : pal.inputBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: rPerms.contains(p.$1)
                                    ? pal.accent
                                    : pal.line,
                              ),
                            ),
                            child: rPerms.contains(p.$1)
                                ? const LIcon(
                                    'Check',
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              perm(p),
                              style: ts(context, 13, weight: w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ], 8),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _pill(
                  context,
                  t('cancel'),
                  color: pal.segmented,
                  onTap: () => setState(() {
                    roleFormOpen = false;
                    editingRole = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _pill(
                  context,
                  t('save'),
                  color: pal.accent,
                  textColor: Colors.white,
                  onTap: () {
                    if (rName.trim().isEmpty) {
                      app.toast(t('fillName'));
                      return;
                    }
                    app.saveRole(
                      LabRole(
                        id:
                            editingRole?.id ??
                            '${DateTime.now().microsecondsSinceEpoch}',
                        name: rName.trim(),
                        description: rDesc.trim(),
                        color: rColor,
                        permissions: List.of(rPerms),
                        isDefault: editingRole?.isDefault ?? false,
                      ),
                    );
                    setState(() {
                      roleFormOpen = false;
                      editingRole = null;
                    });
                  },
                ),
              ),
            ],
          ),
        ]),
      if (deletingRole != null)
        confirmCard(
          app.tr('حذف الدور؟', 'ڕۆڵ بسڕدرێتەوە؟', 'Delete role?'),
          app.roleName(deletingRole!),
          () => setState(() => deletingRole = null),
          () {
            app.deleteRole(deletingRole!);
            setState(() => deletingRole = null);
          },
        ),
      _col([
        for (final r in app.roles)
          () {
            final c = Color(r.color);
            final count = app.users.where((u) => u.roleId == r.id).length;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pal.chipBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: pal.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: .1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          app.roleName(r).characters.first,
                          style: ts(context, 15, weight: w900, color: c),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.roleName(r),
                              style: ts(
                                context,
                                15,
                                weight: w700,
                                height: 1.375,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              app.roleDesc(r),
                              style: ts(context, 12, color: pal.muted),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: pal.segmented,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$count ${t('usersCount')} • ${r.permissions.length} ${t('permissions')}',
                                style: ts(context, 11, weight: w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _openRole(r),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pal.card,
                            shape: BoxShape.circle,
                            border: Border.all(color: pal.cardBorder),
                          ),
                          child: LIcon('Pencil', size: 14, color: pal.ink),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => deletingRole = r),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Fixed.red,
                            shape: BoxShape.circle,
                          ),
                          child: const LIcon(
                            'Trash2',
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._gap([
                    for (final p in kPermissions)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              perm(p),
                              style: ts(context, 13, weight: w700),
                            ),
                          ),
                          Toggle(
                            value: r.permissions.contains(p.$1),
                            onTap: () => app.toggleRolePermission(r, p.$1),
                          ),
                        ],
                      ),
                  ], 8),
                ],
              ),
            );
          }(),
      ], gap: 8),
      if (app.roles.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            t('noRoles'),
            textAlign: TextAlign.center,
            style: ts(context, 13, color: pal.muted),
          ),
        ),
    ]);
  }
}

/// Native-looking `<select>` replacement.
class _SelectBox extends StatelessWidget {
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  final double fontSize;
  final double vPad;
  final double radius;
  final double hPad;

  const _SelectBox({
    required this.value,
    required this.options,
    required this.onChanged,
    this.fontSize = 14,
    this.vPad = 12,
    this.radius = 16,
    this.hPad = 12,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final current = options.where((o) => o.$1 == value);
    return PopupMenuButton<String>(
      onSelected: onChanged,
      color: pal.card,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem(
            value: o.$1,
            child: Text(o.$2, style: ts(context, 14)),
          ),
      ],
      child: Container(
        height: fontSize * 1.5 + vPad * 2 + 2,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        decoration: BoxDecoration(
          color: pal.inputBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: pal.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                current.isNotEmpty ? current.first.$2 : '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(context, fontSize),
              ),
            ),
            Transform.rotate(
              angle: math.pi / 2,
              child: LIcon('ChevronRight', size: 14, color: pal.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Financial

class _Financial extends StatelessWidget {
  const _Financial();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final d = app.d, w = app.w;

    Widget stat(String label, String amount, double pct) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.chipBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ts(context, 11, color: pal.muted)),
          const SizedBox(height: 2),
          Text('$amount IQD', style: ts(context, 15, weight: w700)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              color: pal.dark
                  ? const Color(0xFF2C2C2E)
                  : const Color(0xFFEDEDED),
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: pct / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: pal.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Widget line(String a, String b, {bool accent = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: pal.chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(a, style: ts(context, 13))),
          Text(
            b,
            style: ts(
              context,
              13,
              weight: w700,
              color: accent ? pal.accent : null,
            ),
          ),
        ],
      ),
    );

    Widget sub(String s) => Text(
      s,
      style: ts(context, 12, weight: w700, color: pal.muted),
    );
    // Server numbers when connected; the design's sample numbers in demo mode.
    final f = app.finance;
    String money(num v) => v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    num total(String k) => ((f['totals'] as Map?)?[k] ?? 0) as num;
    num cat(String k) => ((f['byCategory'] as Map?)?[k] ?? 0) as num;
    final income = total('income');
    double pctOf(num v) => income <= 0 ? (v > 0 ? 100 : 0) : (v / income * 100).clamp(0, 100).toDouble();
    const catNames = {
      'rent': ('إيجار', 'کرێ', 'Rent'),
      'salaries': ('رواتب', 'مووچە', 'Salaries'),
      'reagents': ('مواد ومحاليل', 'ماددە', 'Reagents'),
      'electricity': ('كهرباء', 'کارەبا', 'Electricity'),
      'transport': ('نقل', 'گواستنەوە', 'Transport'),
      'maintenance': ('صيانة', 'چاککردنەوە', 'Maintenance'),
      'other': ('أخرى', 'هیتر', 'Other'),
    };
    String catLabel(String k) => catNames[k] == null ? k : app.tr(catNames[k]!.$1, catNames[k]!.$2, catNames[k]!.$3);
    List<(int, int)> bars;
    {
      final inc = [for (final v in ((f['bars'] as Map)['income'] as List)) (v as num).toDouble()];
      final exp = [for (final v in ((f['bars'] as Map)['expenses'] as List)) (v as num).toDouble()];
      final top = [...inc, ...exp, 1.0].reduce((a, b) => a > b ? a : b);
      bars = [for (var i = 0; i < inc.length; i++) ((inc[i] / top * 100).round(), (exp[i] / top * 100).round())];
    }
    final invoices = [
            for (final inv in (f['invoices'] as List))
              ('${inv['code']}', '${inv['name']}', money(inv['amount'] as num), inv['paid'] == true ? 'Paid' : 'Pending'),
          ];
    final expenseList = (f['expenses'] as List?) ?? const [];
    final salaryLines = [
      for (final e in expenseList)
        if (e['category'] == 'salaries') ('${e['note']}'.isNotEmpty ? '${e['note']}' : catLabel('salaries'), money(e['amount'] as num)),
    ];
    final otherLines = [
      for (final e in ((f['byCategory'] as Map?) ?? const {}).entries)
        if (e.key != 'salaries' && e.key != 'rent') (catLabel('${e.key}'), money(e.value as num)),
    ];
    final debtLines = [
      for (final dbt in ((f['debts'] as List?) ?? const [])) ('${dbt['name']}', money(dbt['amount'] as num)),
    ];

    return _sectionBody([
      const _AddExpense(),
      Column(
        children: [
          Row(
            children: [
              Expanded(child: stat('₫ ${d('debts')}', money(total('debts')), pctOf(total('debts')))),
              const SizedBox(width: 8),
              Expanded(child: stat('↗ ${d('profits')}', money(total('profit')), pctOf(total('profit') < 0 ? 0 : total('profit')))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: stat('↓ ${d('expenses')}', money(total('expenses')), pctOf(total('expenses')))),
              const SizedBox(width: 8),
              Expanded(
                child: stat('⌂ ${d('rent')} ${d('perMonth')}', money(cat('rent')), pctOf(cat('rent'))),
              ),
            ],
          ),
        ],
      ),
      stat(d('salaries'), money(cat('salaries')), pctOf(cat('salaries'))),
      Text(d('breakdown'), style: ts(context, 13, weight: w700)),
      _col([
        sub(d('salaries')),
        for (final l in salaryLines) line(l.$1, l.$2),
        sub(d('expenses')),
        for (final l in otherLines) line(l.$1, l.$2),
        sub(d('debts')),
        for (final l in debtLines) line(l.$1, l.$2, accent: true),
      ], gap: 8),
      Text(d('incomeVsExpenses'), style: ts(context, 13, weight: w700)),
      SizedBox(
        height: 100,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: const Cubic(.2, .8, .2, 1),
          builder: (context, g, _) => Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < bars.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          height: bars[i].$1 * g,
                          decoration: BoxDecoration(
                            color: pal.accent,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: bars[i].$2 * g,
                          decoration: BoxDecoration(
                            color: pal.track,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      Row(
        children: [
          Text(
            '■ ${w('todayIncome')}',
            style: ts(context, 11, color: pal.muted),
          ),
          const SizedBox(width: 12),
          Text('■ ${d('expenses')}', style: ts(context, 11, color: pal.muted)),
        ],
      ),
      Text(w('invoices'), style: ts(context, 13, weight: w700)),
      _col([
        for (final inv in invoices)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pal.chipBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: inv.$1,
                          style: const TextStyle(fontWeight: w700),
                        ),
                        TextSpan(text: ' • ${inv.$2}'),
                      ],
                    ),
                    style: ts(context, 13),
                  ),
                ),
                Text(inv.$3, style: ts(context, 13, weight: w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: inv.$4 == 'Paid' ? pal.softGreen : pal.softAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    inv.$4 == 'Paid' ? w('paid') : w('pending'),
                    style: ts(
                      context,
                      11,
                      weight: w700,
                      color: inv.$4 == 'Paid' ? pal.greenText : pal.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ], gap: 8),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Manage tests

/// Records an expense (rent, salaries, reagents…); income comes from patients.
class _AddExpense extends StatefulWidget {
  const _AddExpense();

  @override
  State<_AddExpense> createState() => _AddExpenseState();
}

class _AddExpenseState extends State<_AddExpense> {
  bool open = false;
  String cat = 'reagents';
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    const cats = [
      ('rent', 'إيجار', 'کرێ', 'Rent'),
      ('salaries', 'رواتب', 'مووچە', 'Salaries'),
      ('reagents', 'مواد ومحاليل', 'ماددە', 'Reagents'),
      ('electricity', 'كهرباء', 'کارەبا', 'Electricity'),
      ('transport', 'نقل', 'گواستنەوە', 'Transport'),
      ('maintenance', 'صيانة', 'چاککردنەوە', 'Maintenance'),
      ('other', 'أخرى', 'هیتر', 'Other'),
    ];
    if (!open) {
      return _pill(context, app.tr('+ إضافة مصروف', '+ خەرجی', '+ Add expense'), color: pal.accent, textColor: Colors.white, onTap: () => setState(() => open = true));
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(app.tr('مصروف جديد', 'خەرجی نوێ', 'New expense'), style: ts(context, 14, weight: w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in cats)
                FilterChipPill(label: app.tr(c.$2, c.$3, c.$4), selected: cat == c.$1, onTap: () => setState(() => cat = c.$1)),
            ],
          ),
          const SizedBox(height: 8),
          BoxField(controller: _amount, hint: app.tr('المبلغ (د.ع)', 'بڕ (د.ع)', 'Amount (IQD)'), keyboard: TextInputType.number, ltr: true, fontSize: 14, vPad: 10),
          const SizedBox(height: 8),
          BoxField(controller: _note, hint: app.tr('ملاحظة (مثلاً اسم الموظف)', 'تێبینی', 'Note (e.g. employee name)'), fontSize: 14, vPad: 10),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _pill(context, app.w('cancel'), color: pal.segmented, onTap: () => setState(() => open = false))),
              const SizedBox(width: 8),
              Expanded(
                child: _pill(context, app.tr('حفظ', 'پاشەکەوت', 'Save'), color: pal.accent, textColor: Colors.white, onTap: () async {
                  final v = num.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
                  await app.addExpense(cat, v, _note.text.trim());
                  if (v > 0 && mounted) {
                    setState(() {
                      open = false;
                      _amount.clear();
                      _note.clear();
                    });
                  }
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManageTests extends StatefulWidget {
  const _ManageTests();

  @override
  State<_ManageTests> createState() => _ManageTestsState();
}

class _ManageTestsState extends State<_ManageTests> {
  String? open;
  final Set<String> showRanges = {};
  // new test form
  String nName = '',
      nPrice = '',
      nB2b = '',
      nUnits = 'g/dL',
      nCat = '',
      nNormal = '';
  bool nShowRanges = false;
  List<RangeRow> nRanges = [];
  int formVersion = 0;

  String l3(String en, String ar, String ku) {
    final lang = context.app.lang;
    return lang == 'en'
        ? en
        : lang == 'ar'
        ? ar
        : ku;
  }

  Widget _smallInput(
    String initial,
    ValueChanged<String> onChanged, {
    String? hint,
    double radius = 12,
    double fontSize = 13,
    double vPad = 8,
    double hPad = 8,
    TextInputType? kb,
    Key? key,
  }) {
    return _Small(
      key: key,
      initial: initial,
      onChanged: onChanged,
      hint: hint,
      radius: radius,
      fontSize: fontSize,
      vPad: vPad,
      hPad: hPad,
      keyboard: kb,
    );
  }

  Widget _rangeHeader() {
    final app = context.app;
    final pal = app.palette;
    final d = app.d;
    return Row(
      children: [
        for (final h in [
          d('ageFrom'),
          d('ageTo'),
          d('ageUnitLabel'),
          d('genderLabel'),
          d('normalFrom'),
          d('normalTo'),
        ]) ...[
          if (h != d('ageFrom')) const SizedBox(width: 4),
          Expanded(
            child: Text(
              h,
              style: ts(context, 10, weight: w700, color: pal.muted),
            ),
          ),
        ],
      ],
    );
  }

  Widget _rangeRow(
    RangeRow r,
    ValueChanged<RangeRow> onChanged, {
    bool placeholders = false,
    required String keyPrefix,
  }) {
    final app = context.app;
    final d = app.d, w = app.w;
    Widget cell(Widget c) => Expanded(child: c);
    return Row(
      children: [
        cell(
          _smallInput(
            r.ageFrom,
            (v) => onChanged(r.copyWith(ageFrom: v)),
            radius: 8,
            fontSize: 12,
            hPad: 4,
            kb: TextInputType.number,
            hint: placeholders ? d('ageFrom') : null,
            key: ValueKey('$keyPrefix-af'),
          ),
        ),
        const SizedBox(width: 4),
        cell(
          _smallInput(
            r.ageTo,
            (v) => onChanged(r.copyWith(ageTo: v)),
            radius: 8,
            fontSize: 12,
            hPad: 4,
            kb: TextInputType.number,
            hint: placeholders ? d('ageTo') : null,
            key: ValueKey('$keyPrefix-at'),
          ),
        ),
        const SizedBox(width: 4),
        cell(
          _SelectBox(
            value: r.ageUnit,
            options: [
              ('D', d('dayUnit')),
              ('M', d('monthUnit')),
              ('Y', d('yearUnit')),
            ],
            onChanged: (v) => onChanged(r.copyWith(ageUnit: v)),
            fontSize: 12,
            vPad: 8,
            radius: 8,
            hPad: 4,
          ),
        ),
        const SizedBox(width: 4),
        cell(
          _SelectBox(
            value: r.gender,
            options: [
              ('Both', d('both')),
              ('Male', w('male')),
              ('Female', w('female')),
            ],
            onChanged: (v) => onChanged(r.copyWith(gender: v)),
            fontSize: 12,
            vPad: 8,
            radius: 8,
            hPad: 4,
          ),
        ),
        const SizedBox(width: 4),
        cell(
          _smallInput(
            r.min,
            (v) => onChanged(r.copyWith(min: v)),
            radius: 8,
            fontSize: 12,
            hPad: 4,
            hint: d('normalFrom'),
            key: ValueKey('$keyPrefix-mn'),
          ),
        ),
        const SizedBox(width: 4),
        cell(
          _smallInput(
            r.max,
            (v) => onChanged(r.copyWith(max: v)),
            radius: 8,
            fontSize: 12,
            hPad: 4,
            hint: d('normalTo'),
            key: ValueKey('$keyPrefix-mx'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final d = app.d, w = app.w;
    final addByAge = l3(
      '+ Add normal by age',
      '+ إضافة نورمال حسب العمر',
      '+ زیادکردنی ئاسایی بەپێی تەمەن',
    );
    final hideByAge = l3(
      'Hide normal by age',
      'إخفاء نورمال حسب العمر',
      'شاردنەوە',
    );
    final normalLabel = l3('Normal Range', 'النورمال رينج', 'مەودای ئاسایی');
    final normalPh = l3(
      'e.g. 20-50 ng/mL, Negative, Positive',
      'مثال: 20-50 ng/mL أو Negative أو حسب العمر',
      'بۆ نموونە: 20-50 ng/mL',
    );
    const rangeSeed = RangeRow('0', '99', 'Y', 'Both', '', '');

    Widget outlinePill(
      String label,
      VoidCallback onTap, {
      bool expand = true,
      Widget? child,
    }) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: expand ? 0 : 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pal.chipBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: pal.cardBorder),
        ),
        child: child ?? Text(label, style: ts(context, 12, weight: w700)),
      ),
    );

    final items = <Widget>[];
    for (final test in List.of(kCatalog)) {
      final isOpen = open == test.name;
      void up(CatalogTest t) => app.replaceTest(t);
      items.add(
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: pal.chipBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => open = isOpen ? null : test.name),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          test.name,
                          style: ts(context, 14, weight: w700),
                        ),
                      ),
                      Text(
                        'B2C ${formatNumber(test.price)} • B2B ${formatNumber(test.priceB2B)} IQD',
                        style: ts(context, 12, weight: w700, color: pal.accent),
                      ),
                      const SizedBox(width: 8),
                      Transform.rotate(
                        angle: isOpen ? math.pi / 2 : 0,
                        child: LIcon(
                          'ChevronRight',
                          size: 16,
                          color: pal.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isOpen)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: pal.line)),
                  ),
                  child: _col([
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _labeledSmall(
                                w('price'),
                                test.price.toString(),
                                (v) => up(
                                  test.copyWith(price: int.tryParse(v) ?? 0),
                                ),
                                kb: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _labeledSmall(
                                d('b2bPriceLabel'),
                                test.priceB2B.toString(),
                                (v) => up(
                                  test.copyWith(priceB2B: int.tryParse(v) ?? 0),
                                ),
                                kb: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _labeledSmall(
                                w('units'),
                                test.units,
                                (v) => up(test.copyWith(units: v)),
                                hint: d('unitsPh'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _labeledSmall(
                                d('testCategory'),
                                test.category,
                                (v) => up(test.copyWith(category: v)),
                                hint: d('hairLoss'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(normalLabel, style: ts(context, 12, weight: w700)),
                        const SizedBox(height: 4),
                        _smallInput(
                          test.normalText,
                          (v) => up(test.copyWith(normalText: v)),
                          hint: normalPh,
                          vPad: 10,
                        ),
                        const SizedBox(height: 8),
                        outlinePill(
                          showRanges.contains(test.name) ? hideByAge : addByAge,
                          () {
                            setState(
                              () => showRanges.contains(test.name)
                                  ? showRanges.remove(test.name)
                                  : showRanges.add(test.name),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l3(
                            'Type any text — numbers, words, or both.',
                            'اكتب أي نص — أرقام أو كلمات.',
                            'دەتوانیت هەر دەقێک بنووسیت.',
                          ),
                          style: ts(context, 11, color: pal.muted),
                        ),
                      ],
                    ),
                    if (showRanges.contains(test.name)) _rangeHeader(),
                    if (showRanges.contains(test.name))
                      for (var i = 0; i < test.ranges.length; i++)
                        _rangeRow(test.ranges[i], (r) {
                          final rs = List.of(test.ranges)..[i] = r;
                          up(test.copyWith(ranges: rs));
                        }, keyPrefix: '${test.name}-$i'),
                    Row(
                      children: [
                        if (showRanges.contains(test.name))
                          Expanded(
                            child: outlinePill(
                              addByAge,
                              () => up(
                                test.copyWith(
                                  ranges: [...test.ranges, rangeSeed],
                                ),
                              ),
                            ),
                          ),
                        if (test.ranges.length > 1) ...[
                          const SizedBox(width: 8),
                          outlinePill(
                            '',
                            () => up(
                              test.copyWith(
                                ranges: test.ranges.sublist(
                                  0,
                                  test.ranges.length - 1,
                                ),
                              ),
                            ),
                            expand: false,
                            child: LIcon('Trash2', size: 14, color: pal.ink),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            w('active'),
                            style: ts(context, 13, weight: w700),
                          ),
                        ),
                        Toggle(
                          value: test.on,
                          onTap: () => up(test.copyWith(on: !test.on)),
                        ),
                      ],
                    ),
                    _pill(
                      context,
                      w('save'),
                      color: pal.accent,
                      textColor: Colors.white,
                      vPad: 10,
                      fontSize: 13,
                      onTap: () {
                        setState(() => open = null);
                        app.toast(w('saved'));
                      },
                    ),
                  ]),
                ),
            ],
          ),
        ),
      );
    }

    // add-test form
    Widget roundInput(
      String hint,
      String value,
      ValueChanged<String> onChanged,
      double? width, {
      TextInputType? kb,
      double hPad = 12,
    }) {
      final f = _Small(
        key: ValueKey('new-$hint-$formVersion'),
        initial: value,
        onChanged: onChanged,
        hint: hint,
        radius: 999,
        fontSize: 13,
        vPad: 10,
        hPad: hPad,
        keyboard: kb,
      );
      return width == null ? f : SizedBox(width: width, child: f);
    }

    items.add(
      Container(
        padding: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: pal.line)),
        ),
        child: _col([
          Text(w('addTest'), style: ts(context, 13, weight: w700)),
          LayoutBuilder(
            builder: (context, c) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: math.max(110, c.maxWidth - 98 - 8),
                    child: roundInput(
                      w('testName'),
                      nName,
                      (v) => nName = v,
                      null,
                    ),
                  ),
                  roundInput(
                    w('price'),
                    nPrice,
                    (v) => nPrice = v,
                    90,
                    kb: TextInputType.number,
                  ),
                  roundInput(
                    d('b2bPriceLabel'),
                    nB2b,
                    (v) => nB2b = v,
                    90,
                    kb: TextInputType.number,
                  ),
                  roundInput(
                    d('unitsPh'),
                    nUnits,
                    (v) => nUnits = v,
                    100,
                    hPad: 8,
                  ),
                  roundInput(
                    d('testCategory'),
                    nCat,
                    (v) => nCat = v,
                    100,
                    hPad: 8,
                  ),
                ],
              );
            },
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(normalLabel, style: ts(context, 12, weight: w700)),
              const SizedBox(height: 4),
              _smallInput(
                nNormal,
                (v) => nNormal = v,
                hint: normalPh,
                vPad: 10,
                key: ValueKey('nn-$formVersion'),
              ),
              const SizedBox(height: 8),
              outlinePill(
                nShowRanges ? hideByAge : addByAge,
                () => setState(() => nShowRanges = !nShowRanges),
              ),
            ],
          ),
          if (nShowRanges)
            for (var i = 0; i < nRanges.length; i++)
              _rangeRow(
                nRanges[i],
                (r) => setState(() => nRanges[i] = r),
                placeholders: true,
                keyPrefix: 'new-$formVersion-$i',
              ),
          if (nShowRanges)
            outlinePill(addByAge, () => setState(() => nRanges.add(rangeSeed))),
          _pill(
            context,
            w('addTest'),
            color: pal.accent,
            textColor: Colors.white,
            vPad: 10,
            fontSize: 13,
            onTap: () {
              if (nName.trim().isEmpty) return;
              app.addTest(
                CatalogTest(
                  name: nName.trim(),
                  price: int.tryParse(nPrice) ?? 0,
                  priceB2B: int.tryParse(nB2b) ?? 0,
                  category: nCat.isNotEmpty ? nCat : 'General',
                  on: true,
                  units: nUnits,
                  normalText: nNormal,
                  ranges: [
                    for (final r in nRanges)
                      RangeRow(
                        r.ageFrom.isEmpty ? '0' : r.ageFrom,
                        r.ageTo.isEmpty ? '99' : r.ageTo,
                        r.ageUnit,
                        r.gender,
                        r.min.isEmpty ? '0' : r.min,
                        r.max.isEmpty ? '0' : r.max,
                      ),
                  ],
                ),
              );
              setState(() {
                nName = '';
                nPrice = '';
                nB2b = '';
                nCat = '';
                nNormal = '';
                nRanges = [];
                nShowRanges = false;
                formVersion++;
              });
            },
          ),
        ], gap: 8),
      ),
    );

    return _sectionBody(items);
  }

  Widget _labeledSmall(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    String? hint,
    TextInputType? kb,
  }) {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: ts(context, 11, weight: w700, color: pal.muted),
        ),
        const SizedBox(height: 4),
        _smallInput(value, onChanged, hint: hint, kb: kb),
      ],
    );
  }
}

/// Compact input that keeps its own controller.
class _Small extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  final String? hint;
  final double radius, fontSize, vPad, hPad;
  final TextInputType? keyboard;

  const _Small({
    super.key,
    required this.initial,
    required this.onChanged,
    this.hint,
    this.radius = 12,
    this.fontSize = 13,
    this.vPad = 8,
    this.hPad = 8,
    this.keyboard,
  });

  @override
  State<_Small> createState() => _SmallState();
}

class _SmallState extends State<_Small> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      height: widget.fontSize * 1.5 + widget.vPad * 2 + 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pal.inputBg,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: pal.cardBorder),
      ),
      child: TextField(
        controller: _c,
        onChanged: widget.onChanged,
        keyboardType: widget.keyboard,
        style: ts(context, widget.fontSize),
        strutStyle: StrutStyle(
          fontSize: widget.fontSize,
          height: 1.5,
          forceStrutHeight: true,
        ),
        cursorColor: pal.accent,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: widget.hint,
          hintStyle: ts(context, widget.fontSize, color: pal.placeholder),
          contentPadding: EdgeInsets.symmetric(horizontal: widget.hPad),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create order

class _CreateOrder extends StatefulWidget {
  const _CreateOrder();

  @override
  State<_CreateOrder> createState() => _CreateOrderState();
}

class _CreateOrderState extends State<_CreateOrder> {
  final List<SupplyItem> items = [SupplyItem()];
  String supplier = '', supplierPhone = '', notes = '';
  DateTime? neededBy;
  int version = 0;

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    Widget small(String hint, String initial, ValueChanged<String> on, {bool number = false, double? width}) {
      final f = BoxField(
        key: ValueKey('$hint-$version-${initial.hashCode}'),
        controller: TextEditingController(text: initial),
        hint: hint,
        fontSize: 13,
        vPad: 8,
        keyboard: number ? TextInputType.number : null,
        onChanged: on,
      );
      return width == null ? Expanded(child: f) : SizedBox(width: width, child: f);
    }

    return _sectionBody([
      Text(app.tr('طلبية مواد مختبرية', 'داواکاری کەرەستەی تاقیگە', 'Lab supplies order'), style: ts(context, 16, weight: w700)),
      Text(
        app.tr('اكتب المواد المطلوبة لتصير طلبية PDF ترسلها للمورد.', 'کەرەستەکان بنووسە بۆ PDF.', 'List the supplies you need; it becomes a PDF order for the supplier.'),
        style: ts(context, 12, color: pal.muted),
      ),
      for (var i = 0; i < items.length; i++)
        Row(
          children: [
            small(app.tr('المادة', 'کەرەستە', 'Item'), items[i].name, (v) => items[i].name = v),
            const SizedBox(width: 6),
            small(app.tr('الكمية', 'بڕ', 'Qty'), items[i].qty, (v) => items[i].qty = v, number: true, width: 64),
            const SizedBox(width: 6),
            small(app.tr('الوحدة', 'یەکە', 'Unit'), items[i].unit, (v) => items[i].unit = v, width: 74),
            const SizedBox(width: 6),
            Tap(
              onTap: () => setState(() {
                if (items.length > 1) {
                  items.removeAt(i);
                } else {
                  items[0] = SupplyItem();
                }
                version++;
              }),
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: pal.chipBg, shape: BoxShape.circle),
                child: const LIcon('X', size: 13, color: Color(0xFFFF3B30)),
              ),
            ),
          ],
        ),
      _pill(context, app.tr('+ إضافة مادة', '+ زیادکردن', '+ Add item'), color: pal.chipBg, onTap: () => setState(() => items.add(SupplyItem()))),
      _Field(key: ValueKey('sup-$version'), label: app.tr('المورد', 'دابینکەر', 'Supplier'), initial: supplier, fontSize: 14, vPad: 10, onChanged: (v) => supplier = v),
      _Field(key: ValueKey('sph-$version'), label: app.tr('هاتف المورد', 'تەلەفۆنی دابینکەر', 'Supplier phone'), initial: supplierPhone, ltr: true, keyboard: TextInputType.phone, fontSize: 14, vPad: 10, onChanged: (v) => supplierPhone = v),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(app.tr('مطلوب قبل', 'پێویستە پێش', 'Needed by'), style: ts(context, 12, weight: w700, color: pal.muted)),
          const SizedBox(height: 4),
          Tap(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: neededBy ?? DateTime.now().add(const Duration(days: 3)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => neededBy = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: pal.inputBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: pal.cardBorder)),
              child: Row(children: [
                LIcon('Clock', size: 16, color: pal.muted),
                const SizedBox(width: 8),
                Text(neededBy == null ? app.tr('اختر التاريخ (اختياري)', 'بەروار هەڵبژێرە', 'Pick a date (optional)') : _fmt(neededBy!),
                    style: ts(context, 14, weight: w600, color: neededBy == null ? pal.muted : pal.ink)),
              ]),
            ),
          ),
        ],
      ),
      _Field(key: ValueKey('nts-$version'), label: app.tr('ملاحظات', 'تێبینی', 'Notes'), initial: notes, lines: 2, fontSize: 14, onChanged: (v) => notes = v),
      _pill(
        context,
        app.tr('إنشاء PDF وإرسال', 'دروستکردنی PDF و ناردن', 'Create PDF & send'),
        color: pal.accent,
        textColor: Colors.white,
        icon: 'FileText',
        onTap: () {
          final list = items.where((x) => x.name.trim().isNotEmpty).toList();
          if (list.isEmpty) {
            app.toast(app.tr('اكتب مادة واحدة على الأقل', 'لانیکەم یەک کەرەستە بنووسە', 'Add at least one item'));
            return;
          }
          app.saveSupplyOrder(SupplyOrder(
            no: app.nextSupplyOrderNo,
            date: _fmt(DateTime.now()),
            supplier: supplier.trim(),
            supplierPhone: supplierPhone.trim(),
            neededBy: neededBy == null ? '' : _fmt(neededBy!),
            notes: notes.trim(),
            items: [for (final x in list) SupplyItem(x.name.trim(), x.qty.trim(), x.unit.trim())],
          ));
          setState(() {
            items
              ..clear()
              ..add(SupplyItem());
            supplier = '';
            supplierPhone = '';
            notes = '';
            neededBy = null;
            version++;
          });
        },
      ),
      if (app.supplyOrders.isNotEmpty) ...[
        Text(app.tr('الطلبيات السابقة', 'داواکارییە پێشووەکان', 'Previous orders'), style: ts(context, 14, weight: w700)),
        for (final o in app.supplyOrders.take(20))
          Tap(
            onTap: () => app.shareSupplyOrder(o),
            scale: .98,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('#${o.no} • ${o.supplier.isEmpty ? app.tr('بدون مورد', 'بێ دابینکەر', 'No supplier') : o.supplier}', style: ts(context, 14, weight: w700)),
                    Text('${o.date} • ${o.items.length} ${app.tr('مادة', 'کەرەستە', 'items')}', style: ts(context, 12, color: pal.muted)),
                  ]),
                ),
                LIcon('FileText', size: 18, color: pal.accent),
              ]),
            ),
          ),
      ],
    ]);
  }
}

// ---------------------------------------------------------------------------
// Packages

class _Packages extends StatefulWidget {
  const _Packages();

  @override
  State<_Packages> createState() => _PackagesState();
}

class _PackagesState extends State<_Packages> {
  bool formOpen = false;
  LabPackage? editing;
  String name = '',
      price = '',
      b2b = '',
      category = '',
      oldPrice = '',
      start = '',
      end = '';
  List<String> tests = [];
  bool active = true, offer = false;
  int version = 0;

  void _open([LabPackage? p]) => setState(() {
    editing = p;
    name = p?.name ?? '';
    price = p != null ? '${p.price}' : '';
    b2b = p != null ? '${p.priceB2B}' : '';
    category = p?.category ?? '';
    tests = p != null ? List.of(p.tests) : [];
    active = p?.active ?? true;
    offer = p?.isOffer ?? false;
    oldPrice = (p?.oldPrice ?? 0) > 0 ? '${p!.oldPrice}' : '';
    start = p?.startDate ?? '';
    end = p?.endDate ?? '';
    formOpen = true;
    version++;
  });

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final d = app.d, w = app.w;
    Widget f(
      String label,
      String v,
      ValueChanged<String> on, {
      String? hint,
      double size = 14,
      double labelSize = 12,
      TextInputType? kb,
      double hPad = 12,
    }) => _Field(
      key: ValueKey('$label-$version'),
      label: label,
      initial: v,
      hint: hint,
      fontSize: size,
      labelSize: labelSize,
      vPad: 10,
      radius: 12,
      keyboard: kb,
      onChanged: on,
    );

    return _sectionBody([
      _pill(
        context,
        '+ ${d('addPackage')}',
        color: pal.accent,
        textColor: Colors.white,
        onTap: _open,
      ),
      if (formOpen)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pal.cardBorder),
          ),
          child: _col([
            f(d('packageName'), name, (v) => name = v, hint: d('hairLoss')),
            Row(
              children: [
                Expanded(
                  child: f(
                    d('packagePrice'),
                    price,
                    (v) => price = v,
                    size: 13,
                    labelSize: 11,
                    kb: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: f(
                    d('packageB2BPrice'),
                    b2b,
                    (v) => b2b = v,
                    size: 13,
                    labelSize: 11,
                    kb: TextInputType.number,
                  ),
                ),
              ],
            ),
            f(
              d('packageCategory'),
              category,
              (v) => category = v,
              hint: d('hairLoss'),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d('testsInPackage'),
                  style: ts(context, 12, weight: w700, color: pal.muted),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in kCatalog)
                      GestureDetector(
                        onTap: () => setState(
                          () => tests.contains(t.name)
                              ? tests.remove(t.name)
                              : tests.add(t.name),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: tests.contains(t.name)
                                ? pal.accent
                                : pal.chipBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            t.name,
                            style: ts(
                              context,
                              12,
                              weight: w700,
                              color: tests.contains(t.name)
                                  ? Colors.white
                                  : pal.muted2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    d('offerPackage'),
                    style: ts(context, 13, weight: w700),
                  ),
                ),
                Toggle(
                  value: offer,
                  onTap: () => setState(() => offer = !offer),
                ),
              ],
            ),
            if (offer)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: f(
                          d('oldPrice'),
                          oldPrice,
                          (v) => oldPrice = v,
                          size: 13,
                          labelSize: 11,
                          kb: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: f(
                          d('offerPrice'),
                          price,
                          (v) => price = v,
                          size: 13,
                          labelSize: 11,
                          kb: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: f(
                          d('startDate'),
                          start,
                          (v) => start = v,
                          size: 13,
                          labelSize: 11,
                          kb: TextInputType.datetime,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: f(
                          d('endDate'),
                          end,
                          (v) => end = v,
                          size: 13,
                          labelSize: 11,
                          kb: TextInputType.datetime,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    d('packageActive'),
                    style: ts(context, 13, weight: w700),
                  ),
                ),
                Toggle(
                  value: active,
                  onTap: () => setState(() => active = !active),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _pill(
                    context,
                    w('cancel'),
                    color: pal.segmented,
                    vPad: 10,
                    fontSize: 13,
                    onTap: () => setState(() => formOpen = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _pill(
                    context,
                    w('save'),
                    color: pal.accent,
                    textColor: Colors.white,
                    vPad: 10,
                    fontSize: 13,
                    onTap: () {
                      if (name.trim().isEmpty || tests.isEmpty) {
                        app.toast(d('packageName'));
                        return;
                      }
                      app.savePackage(
                        LabPackage(
                          id:
                              editing?.id ??
                              'pkg-${DateTime.now().microsecondsSinceEpoch}',
                          code: editing?.code ?? '',
                          name: name.trim(),
                          category: category.trim().isNotEmpty
                              ? category.trim()
                              : name.trim(),
                          aliases: editing?.aliases ?? const [],
                          tests: List.of(tests),
                          price: int.tryParse(price) ?? 0,
                          priceB2B: int.tryParse(b2b) ?? 0,
                          active: active,
                          isOffer: offer,
                          oldPrice: int.tryParse(oldPrice) ?? 0,
                          startDate: start,
                          endDate: end,
                        ),
                      );
                      setState(() => formOpen = false);
                    },
                  ),
                ),
              ],
            ),
          ], gap: 8),
        ),
      for (final p in List.of(kPackages))
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.chipBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(p.name, style: ts(context, 14, weight: w700)),
                        if (p.isOffer)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Fixed.red,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              d('offerBadge'),
                              style: ts(
                                context,
                                10,
                                weight: w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${d('categoryLabel')}: ${p.category} • ${p.tests.join(', ')}',
                      style: ts(context, 12, color: pal.muted),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (p.isOffer && p.oldPrice > 0)
                            TextSpan(
                              text: '${formatNumber(p.oldPrice)} ',
                              style: TextStyle(
                                color: pal.muted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          TextSpan(
                            text:
                                '${formatNumber(p.price)} IQD • B2B ${formatNumber(p.priceB2B)}'
                                '${p.isOffer && p.startDate.isNotEmpty ? ' • ${p.startDate} → ${p.endDate}' : ''}',
                          ),
                        ],
                      ),
                      style: ts(context, 12, weight: w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => _open(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        w('edit'),
                        style: ts(context, 12, weight: w700, color: pal.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Toggle(
                    value: p.active,
                    onTap: () => app.togglePackageActive(p),
                  ),
                ],
              ),
            ],
          ),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// About

class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final d = app.d;
    Widget info(String a, String b, {bool ltr = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pal.chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(a, style: ts(context, 13, color: pal.muted)),
          ),
          Text(
            b,
            textDirection: ltr ? TextDirection.ltr : null,
            style: ts(context, 13, weight: w700),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Entrance.pop(
        child: CardBox(
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: pal.cardBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(17, 17, 17, .12),
                      offset: Offset(0, 6),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.jpg',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Text('LabGo', style: ts(context, 20, weight: w900)),
              Text(d('versionLabel'), style: ts(context, 12, color: pal.muted)),
              const SizedBox(height: 8),
              Text(
                d('aboutDesc'),
                textAlign: TextAlign.center,
                style: ts(context, 13, color: pal.muted2, height: 1.625),
              ),
              const SizedBox(height: 12),
              info(d('developerLabel'), 'LabGo LLC'),
              const SizedBox(height: 8),
              Tap(
                onTap: () => launchUrl(Uri.parse('tel:+9647777430067')),
                child: info(d('contactLabel'), '+964 777 743 0067', ltr: true),
              ),
              const SizedBox(height: 8),
              Tap(
                onTap: () => launchUrl(Uri.parse('mailto:info@labgo-iq.com')),
                child: info(app.tr('البريد', 'ئیمەیڵ', 'Email'), 'info@labgo-iq.com', ltr: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _pill(
                      context,
                      d('privacyLabel'),
                      color: pal.chipBg,
                      vPad: 10,
                      fontSize: 12,
                      onTap: () => launchUrl(Uri.parse('$kSiteUrl/privacy-policy'), mode: LaunchMode.externalApplication),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _pill(
                      context,
                      d('termsLabel'),
                      color: pal.chipBg,
                      vPad: 10,
                      fontSize: 12,
                      onTap: () => showTermsPage(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reports (header / footer, previews, templates)

class _Reports extends StatefulWidget {
  const _Reports();

  @override
  State<_Reports> createState() => _ReportsState();
}

/// Report management: a live preview of the result report (the same PDF the
/// app and the server print), and what each part of it comes from.
class _ReportsState extends State<_Reports> {
  Future<Uint8List?>? _preview;
  String _sig = '';

  Patient _sample(AppState app) {
    final withResults = app.patients.where((p) => p.results.values.any((v) => v.trim().isNotEmpty));
    final p = withResults.isNotEmpty ? withResults.first : (app.patients.isNotEmpty ? app.patients.first : kPatientsSeed.first);
    return p.results.isEmpty ? p.copyWith(results: {for (final t in p.tests) t: '12'}) : p;
  }

  Future<Uint8List?> _render(AppState app) async {
    try {
      final bytes = await buildResultReportPdf(app, _sample(app));
      await for (final page in Printing.raster(bytes, pages: const [0], dpi: 110)) {
        return await page.toPng();
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final sig = [app.labName, app.labPhone, app.labAddress, app.labEmail, app.labWebsite, ...app.holderLines, app.palette.accent.toARGB32(), app.labLogo?.length, app.platformFooter].join('|');
    if (sig != _sig) {
      _sig = sig;
      _preview = _render(app);
    }
    Widget row(String icon, String title, String text, {Widget? trailing}) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: pal.softAccent, shape: BoxShape.circle),
                child: LIcon(icon, size: 16, color: pal.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ts(context, 13, weight: w700)),
                    Text(text, style: ts(context, 12, color: pal.muted, height: 1.4)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        );
    return _sectionBody([
      Text(app.tr('معاينة تقرير النتائج', 'پێشبینینی ڕاپۆرت', 'Result report preview'), style: ts(context, 14, weight: w700)),
      Tap(
        onTap: () => app.previewSampleReport(_sample(app)),
        scale: .98,
        child: Container(
          constraints: const BoxConstraints(minHeight: 200),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: pal.line)),
          child: FutureBuilder<Uint8List?>(
            future: _preview,
            builder: (context, snap) => snap.data != null
                ? Image.memory(snap.data!, fit: BoxFit.fitWidth, gaplessPlayback: true)
                : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        ),
      ),
      row(
        'Building2',
        app.tr('الترويسة', 'سەرپەڕە', 'Header'),
        app.tr('شعار المختبر واسمه وأصحاب الإجازات والعنوان والهاتف والبريد — من «بيانات المختبر».', 'لۆگۆ و ناو و خاوەن مۆڵەتەکان و ناونیشان — لە «زانیاری تاقیگە».', 'Lab logo, name, licence holders, address, phone and email — from "Lab data".'),
        trailing: Tap(
          onTap: () => app.updateSettings(() => app.openSection = 'labData'),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(app.tr('تعديل', 'دەستکاری', 'Edit'), style: ts(context, 12, weight: w700, color: pal.accent)),
          ),
        ),
      ),
      row('Pencil', app.tr('لون التقرير', 'ڕەنگی ڕاپۆرت', 'Report colour'), app.tr('يتبع لون التطبيق الذي تختاره من «تغيير اللون».', 'ڕەنگی ئەپ بەکاردێنێت.', 'Follows the app colour you choose in "Change Color".'),
          trailing: Container(width: 18, height: 18, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: pal.accent, shape: BoxShape.circle))),
      row('QrCode', app.tr('التحقق', 'پشتڕاستکردنەوە', 'Verification'), app.tr('باركود رقم الطلب في العنوان، ورمز QR للتحقق من صحة التقرير.', 'بارکۆد و QR بۆ پشتڕاستکردنەوە.', 'Order barcode in the title bar and a QR code to verify the report.')),
      row(
        'BadgeCheck',
        app.tr('الذيل — منصة LabGo', 'پەراوێز — LabGo', 'Footer — LabGo platform'),
        app.platformFooter
            ? app.tr('يظهر «Powered by LabGo» مع الشعار. لا يمكن إزالته إلا من لوحة الإدارة العامة.', 'تەنها لە پانێڵی بەڕێوەبردن لادەبرێت.', 'Shows "Powered by LabGo" with the logo. Only the LabGo admin panel can remove it.')
            : app.tr('أُزيل بواسطة إدارة LabGo.', 'لەلایەن LabGo لابرا.', 'Removed by the LabGo admin.'),
      ),
      _pill(
        context,
        app.tr('معاينة وطباعة PDF', 'پێشبینین و چاپی PDF', 'Preview & print PDF'),
        color: pal.accent,
        textColor: Colors.white,
        icon: 'Printer',
        onTap: () => app.previewSampleReport(_sample(app)),
      ),
    ]);
  }
}

/// One licence holder row (title, name, specialty) in "Lab data".
class _HolderRow extends StatefulWidget {
  final LicenseHolder holder;
  final VoidCallback onRemove;
  const _HolderRow({super.key, required this.holder, required this.onRemove});

  @override
  State<_HolderRow> createState() => _HolderRowState();
}

class _HolderRowState extends State<_HolderRow> {
  late final _title = TextEditingController(text: widget.holder.title);
  late final _name = TextEditingController(text: widget.holder.name);
  late final _spec = TextEditingController(text: widget.holder.specialty);

  @override
  void dispose() {
    _title.dispose();
    _name.dispose();
    _spec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 76,
                child: BoxField(controller: _title, hint: 'Dr.', ltr: true, fontSize: 13, vPad: 8, onChanged: (v) => app.updateLab(() => widget.holder.title = v)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: BoxField(controller: _name, hint: app.tr('الاسم', 'ناو', 'Name'), fontSize: 13, vPad: 8, onChanged: (v) => app.updateLab(() => widget.holder.name = v)),
              ),
              const SizedBox(width: 6),
              Tap(
                onTap: widget.onRemove,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: pal.card, shape: BoxShape.circle),
                  child: const LIcon('X', size: 14, color: Color(0xFFFF3B30)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          BoxField(controller: _spec, hint: app.tr('الاختصاص (مثلاً Bacteriologist)', 'پسپۆڕی', 'Specialty (e.g. Bacteriologist)'), fontSize: 13, vPad: 8, onChanged: (v) => app.updateLab(() => widget.holder.specialty = v)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lab data: the same fields as the web settings; saved to the server as you type.

class LabDataCard extends StatelessWidget {
  final bool inner;
  const LabDataCard({super.key, this.inner = false});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final d = app.d;
    final holders = app.licenseHolders;
    return CardBox(
      child: _col([
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: pal.cardBorder)),
                child: app.labLogo != null
                    ? Image.memory(app.labLogo!, width: 88, height: 88, fit: BoxFit.contain)
                    : Image.asset('assets/images/logo.jpg', width: 88, height: 88, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.tr('شعار المختبر', 'لۆگۆی تاقیگە', 'Lab logo'), style: ts(context, 14, weight: w700)),
                    Text(app.tr('يظهر في رأس تقرير النتائج', 'لە سەرپەڕەی ڕاپۆرت دەردەکەوێت', 'Shown in the report header'), style: ts(context, 11, color: pal.muted)),
                    const SizedBox(height: 8),
                    _pill(
                      context,
                      app.tr('تغيير الشعار', 'گۆڕینی لۆگۆ', 'Change logo'),
                      onTap: app.pickLabLogo,
                      color: pal.accent,
                      textColor: Colors.white,
                      vPad: 8,
                      fontSize: 12,
                      shrink: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _Field(label: d('labNameLabel'), initial: app.labName, fontSize: 14, vPad: 10, onChanged: (v) => app.updateLab(() {
          app.labName = v;
          app.labDisplayName = v.trim().isEmpty ? app.labDisplayName : v.trim();
        })),
        _Field(label: d('phoneLabel'), initial: app.labPhone, ltr: true, fontSize: 14, vPad: 10, keyboard: TextInputType.phone, onChanged: (v) => app.updateLab(() => app.labPhone = v)),
        _Field(label: app.tr('البريد الإلكتروني', 'ئیمەیڵ', 'Email'), initial: app.labEmail, ltr: true, fontSize: 14, vPad: 10, keyboard: TextInputType.emailAddress, onChanged: (v) => app.updateLab(() => app.labEmail = v)),
        _Field(label: app.tr('الموقع الإلكتروني', 'ماڵپەڕ', 'Website'), initial: app.labWebsite, hint: 'www.example.com', ltr: true, fontSize: 14, vPad: 10, keyboard: TextInputType.url, onChanged: (v) => app.updateLab(() => app.labWebsite = v)),
        _Field(label: d('addressLabel'), initial: app.labAddress, fontSize: 14, vPad: 10, onChanged: (v) => app.updateLab(() => app.labAddress = v)),
        _Field(label: app.tr('نبذة عن المختبر', 'دەربارەی تاقیگە', 'About the lab'), initial: app.labDescription, fontSize: 14, vPad: 10, lines: 3, onChanged: (v) => app.updateLab(() => app.labDescription = v)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(app.tr('أصحاب الإجازات', 'خاوەن مۆڵەتەکان', 'Licence holders'), style: ts(context, 13, weight: w700)),
            Text(app.tr('تظهر في رأس التقرير — اللقب والاسم والاختصاص (6 كحد أقصى)', 'لە سەرپەڕەی ڕاپۆرت — نازناو، ناو، پسپۆڕی (تا 6)', 'Shown in the report header — title, name and specialty (up to 6)'), style: ts(context, 11, color: pal.muted)),
            const SizedBox(height: 8),
            for (var i = 0; i < holders.length; i++) ...[
              _HolderRow(
                key: ObjectKey(holders[i]),
                holder: holders[i],
                onRemove: () => app.updateLab(() => app.licenseHolders = [...holders]..removeAt(i)),
              ),
              const SizedBox(height: 8),
            ],
            if (holders.length < 6)
              _pill(
                context,
                app.tr('+ إضافة صاحب إجازة', '+ زیادکردن', '+ Add licence holder'),
                color: pal.chipBg,
                onTap: () => app.updateLab(() => app.licenseHolders = [...holders, LicenseHolder('Dr.', '', '')]),
              ),
          ],
        ),
        _Field(label: d('footerLabel'), initial: app.labFooter, fontSize: 14, vPad: 10, onChanged: (v) => app.updateSettings(() => app.labFooter = v)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Accent colour

class _ColorPicker extends StatelessWidget {
  const _ColorPicker();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final current = kAccents.firstWhere(
      (a) => a.key == app.accentKey,
      orElse: () => kAccents.first,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Entrance.pop(
        child: CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.w('colorHint'),
                style: ts(context, 12, color: pal.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final a in kAccents)
                    Tap(
                      scale: .9,
                      onTap: () =>
                          app.updateSettings(() => app.accentKey = a.key),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: app.darkMode ? a.darkHex : a.hex,
                          shape: BoxShape.circle,
                        ),
                        child: app.accentKey == a.key
                            ? const LIcon(
                                'Check',
                                size: 20,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(current.label, style: ts(context, 13, weight: w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Waste management page (design `k0`)

class _WastePage extends StatefulWidget {
  const _WastePage();

  @override
  State<_WastePage> createState() => _WastePageState();
}

class _WastePageState extends State<_WastePage> {
  bool formOpen = false;
  String type = 'Sharps', weight = '', notes = '';
  DateTime date = DateTime.now();
  int version = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final d = app.d, w = app.w;

    Widget chips(
      List<(String, String)> items,
      String value,
      ValueChanged<String> onTap,
    ) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final it in items)
          GestureDetector(
            onTap: () => onTap(it.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: value == it.$1 ? pal.accent : pal.chipBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                it.$2,
                style: ts(
                  context,
                  12,
                  weight: w700,
                  color: value == it.$1 ? Colors.white : pal.muted2,
                ),
              ),
            ),
          ),
      ],
    );

    String fmtWeight(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        112 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BackLink(
              label: w('back'),
              onTap: () => app.updateSettings(() => app.wastePage = false),
            ),
          ),
          Text(w('wasteTitle'), style: ts(context, 28, weight: w700)),
          const SizedBox(height: 12),
          _pill(
            context,
            d('transferRequest'),
            color: pal.accent,
            textColor: Colors.white,
            vPad: 16,
            icon: 'Trash2',
            iconSize: 18,
            onTap: () => setState(() => formOpen = !formOpen),
          ),
          if (formOpen)
            _sectionBody([
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d('wasteType'),
                    style: ts(context, 12, weight: w700, color: pal.muted),
                  ),
                  const SizedBox(height: 4),
                  chips(
                    [
                      ('Sharps', w('sharps')),
                      ('Biohazard', w('biohazard')),
                      ('Chemical', w('chemical')),
                      ('General', w('general')),
                    ],
                    type,
                    (v) => setState(() => type = v),
                  ),
                ],
              ),
              _Field(
                key: ValueKey('w-$version'),
                label: w('weightLabel'),
                initial: weight,
                hint: app.tr('الوزن بالكيلو', 'کیلۆ', 'Weight in kg'),
                fontSize: 14,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => weight = v,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d('pickupDate'), style: ts(context, 12, weight: w700, color: pal.muted)),
                  const SizedBox(height: 4),
                  Tap(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) setState(() => date = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: pal.inputBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: pal.cardBorder)),
                      child: Row(
                        children: [
                          LIcon('Clock', size: 16, color: pal.muted),
                          const SizedBox(width: 8),
                          Text('${date.day}/${date.month}/${date.year}', style: ts(context, 14, weight: w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _Field(
                key: ValueKey('nt-$version'),
                label: d('notesLabel'),
                initial: notes,
                fontSize: 14,
                lines: 2,
                onChanged: (v) => notes = v,
              ),
              _pill(
                context,
                d('submitRequest'),
                color: pal.accent,
                textColor: Colors.white,
                onTap: () {
                  final kg = double.tryParse(weight);
                  if (kg == null || kg <= 0) {
                    app.toast(w('weightLabel'));
                    return;
                  }
                  final two = (int v) => v.toString().padLeft(2, '0');
                  app.addWasteTransfer(
                    WasteTransfer(
                      id: '${DateTime.now().microsecondsSinceEpoch}',
                      date: '${date.year}-${two(date.month)}-${two(date.day)}',
                      type: type,
                      weight: kg,
                      notes: notes,
                    ),
                  );
                  setState(() {
                    weight = '';
                    notes = '';
                    date = DateTime.now();
                    formOpen = false;
                    version++;
                  });
                },
              ),
            ]),
          const SizedBox(height: 16),
          Text(d('transferLog'), style: ts(context, 16, weight: w700)),
          for (final t in app.wasteTransfers) ...[
            const SizedBox(height: 8),
            Tap(
              onTap: () => app.openWasteReport(t),
              scale: .98,
              child: CardBox(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: pal.softAccent, shape: BoxShape.circle),
                      child: LIcon('Trash2', size: 18, color: pal.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t.type == 'Sharps' ? w('sharps') : t.type == 'Biohazard' ? w('biohazard') : t.type == 'Chemical' ? w('chemical') : w('general')} • ${fmtWeight(t.weight)} ${w('kg')}',
                            style: ts(context, 15, weight: w700),
                          ),
                          Text(
                            '${t.requestNo > 0 ? '#${t.requestNo} • ' : ''}${t.date}${t.notes.isNotEmpty ? ' • ${t.notes}' : ''}',
                            style: ts(context, 12, color: pal.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        LIcon('FileText', size: 18, color: pal.accent),
                        Text('PDF', style: ts(context, 10, weight: w700, color: pal.accent)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Terms of use, shown inside the app (works offline).
void showTermsPage(BuildContext context) {
  final app = AppScope.read(context);
  final ar = app.lang != 'en';
  final sections = ar
      ? const [
          ('1. القبول', 'باستخدامك تطبيق LabGo Lab أو لوحة المختبرات فإنك توافق على هذه الشروط. إذا لم توافق عليها فلا تستخدم المنصة.'),
          ('2. حسابات المختبرات', 'المختبر مسؤول عن صحة بياناته وبيانات أصحاب الإجازات، وعن حسابات موظفيه وصلاحياتهم، وعن سرية كلمات المرور.'),
          ('3. النتائج والتقارير', 'المختبر وحده مسؤول عن دقة النتائج المدخلة واعتمادها. LabGo منصة لإدارة البيانات ولا تقدم تشخيصاً طبياً. تحمل التقارير رمز تحقق ويُمنع تعديلها بعد الاعتماد خارج المنصة.'),
          ('4. بيانات المرضى', 'تُستخدم بيانات المرضى لتقديم الخدمة فقط وفق سياسة الخصوصية، ويلتزم المختبر بعدم استخدامها لأي غرض آخر.'),
          ('5. التحويل بين المختبرات والمتجر', 'الأسعار المتفق عليها بين المختبرات وطلبات المتجر والمزادات مسؤولية الأطراف المعنية. لا يُعرض أي منتج أو مزاد أو مختبر للبيع إلا بعد مراجعة إدارة LabGo.'),
          ('6. النفايات الطبية', 'يلتزم المختبر بتصنيف النفايات الطبية ووزنها بدقة عند طلب النقل وتسليمها مع تقرير الطلب.'),
          ('7. التعديلات والتواصل', 'قد نحدّث هذه الشروط، ويُعد استمرار الاستخدام موافقة عليها. للتواصل: info@labgo-iq.com — +964 777 743 0067 — LabGo LLC.'),
        ]
      : const [
          ('1. Acceptance', 'By using LabGo Lab or the lab dashboard you agree to these terms. If you do not agree, do not use the platform.'),
          ('2. Lab accounts', 'The lab is responsible for its details and licence holders, its staff accounts and permissions, and keeping passwords private.'),
          ('3. Results and reports', 'The lab alone is responsible for the results it enters and approves. LabGo manages data and does not give medical diagnoses. Reports carry a verification code and may not be altered outside the platform after approval.'),
          ('4. Patient data', 'Patient data is used only to provide the service, under the privacy policy, and the lab must not use it for anything else.'),
          ('5. Transfers and the store', 'Prices agreed between labs, store orders and auctions are the parties\' responsibility. No product, auction or lab for sale is shown before LabGo reviews it.'),
          ('6. Medical waste', 'The lab must classify and weigh medical waste accurately when requesting pickup and hand it over with the request report.'),
          ('7. Changes and contact', 'We may update these terms; continued use means you accept them. Contact: info@labgo-iq.com — +964 777 743 0067 — LabGo LLC.'),
        ];
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (ctx) {
      final pal = app.palette;
      return Directionality(
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: pal.appBg,
          appBar: AppBar(
            backgroundColor: pal.appBg,
            foregroundColor: pal.ink,
            elevation: 0,
            title: Text(ar ? 'شروط الاستخدام' : 'Terms of Use', style: ts(ctx, 17, weight: w700)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              for (final sct in sections)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: pal.cardBorder)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sct.$1, style: ts(ctx, 15, weight: w700, color: pal.accent)),
                      const SizedBox(height: 4),
                      Text(sct.$2, style: ts(ctx, 13.5, color: pal.ink, height: 1.7)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  ));
}

/// Support: a suggestion, a bug report or a problem, with photos; the LabGo
/// team receives it in the admin panel and the lab gets a ticket number.
class _Support extends StatefulWidget {
  const _Support();

  @override
  State<_Support> createState() => _SupportState();
}

class _SupportState extends State<_Support> {
  String type = 'suggestion';
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final List<Uint8List> images = [];
  bool sending = false;

  @override
  void initState() {
    super.initState();
    AppScope.read(context).loadSupport();
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final types = [
      ('suggestion', app.tr('اقتراح تطوير', 'پێشنیار', 'Suggestion')),
      ('bug', app.tr('خطأ في النظام', 'هەڵە', 'Bug')),
      ('problem', app.tr('مشكلة', 'کێشە', 'Problem')),
      ('other', app.tr('أخرى', 'هیتر', 'Other')),
    ];
    String typeName(String k) => types.firstWhere((t) => t.$1 == k, orElse: () => types.last).$2;
    String statusName(String k) => switch (k) {
          'in_progress' => app.tr('قيد المعالجة', 'لە کاردایە', 'In progress'),
          'closed' => app.tr('مغلق', 'داخراو', 'Closed'),
          _ => app.tr('مستلم', 'وەرگیرا', 'Received'),
        };
    return _sectionBody([
      Text(app.tr('راسل فريق LabGo', 'نامە بۆ تیمی LabGo', 'Write to the LabGo team'), style: ts(context, 16, weight: w700)),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final t in types) FilterChipPill(label: t.$2, selected: type == t.$1, onTap: () => setState(() => type = t.$1)),
      ]),
      BoxField(controller: _subject, hint: app.tr('العنوان (اختياري)', 'ناونیشان', 'Subject (optional)'), fontSize: 14, vPad: 10),
      BoxField(controller: _message, hint: app.tr('اكتب التفاصيل…', 'وردەکاری بنووسە…', 'Describe it…'), lines: 5, fontSize: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < images.length; i++)
            Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(images[i], width: 72, height: 72, fit: BoxFit.cover)),
              PositionedDirectional(
                top: 2,
                end: 2,
                child: Tap(
                  onTap: () => setState(() => images.removeAt(i)),
                  child: Container(width: 22, height: 22, alignment: Alignment.center, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const LIcon('X', size: 12, color: Colors.white)),
                ),
              ),
            ]),
          if (images.length < 6)
            Tap(
              onTap: () async {
                final picked = await app.pickImages(max: 6 - images.length);
                if (picked.isNotEmpty) setState(() => images.addAll(picked));
              },
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: pal.line)),
                child: LIcon('ImagePlus', size: 22, color: pal.accent),
              ),
            ),
        ],
      ),
      _pill(
        context,
        sending ? '…' : app.tr('إرسال البلاغ', 'ناردن', 'Send'),
        color: pal.accent,
        textColor: Colors.white,
        icon: 'Send',
        onTap: () async {
          if (sending) return;
          setState(() => sending = true);
          final no = await app.sendSupport(type, _subject.text.trim(), _message.text.trim(), List.of(images));
          if (!mounted) return;
          setState(() => sending = false);
          if (no == null) return;
          _subject.clear();
          _message.clear();
          setState(() => images.clear());
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: pal.card,
              title: Text(app.tr('تم إرسال البلاغ ✓', 'نێردرا ✓', 'Sent ✓'), style: ts(ctx, 18, weight: w700)),
              content: Text(
                app.tr('رقم البلاغ: #$no\nسيصلك إشعار عند رد فريق LabGo.', 'ژمارە: #$no', 'Ticket number: #$no\nYou will be notified when the LabGo team replies.'),
                style: ts(ctx, 14, height: 1.6),
              ),
              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(app.tr('حسناً', 'باشە', 'OK'), style: ts(ctx, 14, weight: w700, color: pal.accent)))],
            ),
          );
        },
      ),
      if (app.supportTickets.isNotEmpty) ...[
        Text(app.tr('بلاغاتي', 'نامەکانم', 'My tickets'), style: ts(context, 14, weight: w700)),
        for (final t in app.supportTickets.take(20))
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text('#${t['ticketNo']} • ${typeName('${t['type']}')}', style: ts(context, 14, weight: w700))),
                  Text(statusName('${t['status']}'), style: ts(context, 12, weight: w700, color: pal.accent)),
                ]),
                Text('${t['message']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(context, 12, color: pal.muted)),
                if ('${t['adminReply'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('${app.tr('رد LabGo', 'وەڵامی LabGo', 'LabGo reply')}: ${t['adminReply']}', style: ts(context, 12, weight: w600)),
                ],
              ],
            ),
          ),
      ],
    ]);
  }
}
