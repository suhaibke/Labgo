import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../catalog_data.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import 'add_screen.dart' show formatNumber;

// ---------------------------------------------------------------------------
// small shared pieces

List<Widget> _gap(List<Widget> items, double gap) => [
  for (var i = 0; i < items.length; i++) ...[
    if (i > 0) SizedBox(height: gap),
    items[i],
  ],
];

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
      ('reports', w('manageReports'), 'FileText'),
      ('labData', d('labData'), 'Building2'),
      ('color', w('changeColor'), 'Pencil'),
    ];

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
                  decoration: BoxDecoration(
                    color: pal.avatarBg,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
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
                gradient: Fixed.sendGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(255, 107, 0, .35),
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
    final note = app.tr(
      'رفع الصور من الاستوديو غير متاح بعد',
      'بەرزکردنەوە لە ستۆدیۆ هێشتا بەردەست نییە',
      'Photo uploads from Studio are not available yet',
    );
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
              decoration: BoxDecoration(
                color: pal.avatarBg,
                shape: BoxShape.circle,
              ),
              child: Text(shown, style: ts(context, 26, weight: w700)),
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
                  Text(
                    note,
                    style: ts(context, 11, color: pal.muted, height: 1.375),
                  ),
                  const SizedBox(height: 8),
                  _pill(
                    context,
                    app.tr('تغيير الصورة', 'گۆڕینی وێنە', 'Change Image'),
                    onTap: () => app.toast(note),
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
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            d('avatarLabel'),
            style: ts(context, 12, weight: w700, color: pal.muted),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pal.avatarBg,
                  shape: BoxShape.circle,
                ),
                child: Text(shown, style: ts(context, 18, weight: w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BoxField(
                  key: ValueKey('avatar-$avatar'),
                  controller: TextEditingController(text: avatar),
                  hint: 'A',
                  onChanged: (v) => setState(
                    () => avatar = v.length > 2 ? v.substring(0, 2) : v,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              for (final l in const ['A', 'D', 'S', 'L']) ...[
                if (l != 'A') const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => avatar = l),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: avatar == l ? pal.accent : pal.chipBg,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      l,
                      style: ts(
                        context,
                        13,
                        weight: w700,
                        color: avatar == l ? Colors.white : pal.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
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
    const bars = [(80, 45), (90, 55), (70, 40), (95, 60), (85, 50), (100, 65)];
    final invoices = [
      ('INV-124', 'Ali Ahmed', '25,000', 'Paid'),
      ('INV-125', 'Sara Ali', '40,000', 'Pending'),
      ('INV-126', 'Layla Hassan', '10,000', 'Paid'),
    ];

    return _sectionBody([
      Column(
        children: [
          Row(
            children: [
              Expanded(child: stat('₫ ${d('debts')}', '450,000', 30)),
              const SizedBox(width: 8),
              Expanded(child: stat('↗ ${d('profits')}', '1,200,000', 85)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: stat('↓ ${d('expenses')}', '680,000', 55)),
              const SizedBox(width: 8),
              Expanded(
                child: stat('⌂ ${d('rent')} ${d('perMonth')}', '500,000', 40),
              ),
            ],
          ),
        ],
      ),
      stat(d('salaries'), '2,100,000', 90),
      Text(d('breakdown'), style: ts(context, 13, weight: w700)),
      _col([
        sub(d('salaries')),
        line(d('salaryAhmed'), '800,000'),
        line(d('salarySara'), '700,000'),
        line(d('salaryOmar'), '600,000'),
        sub(d('expenses')),
        line(d('expReagents'), '300,000'),
        line(d('expElectricity'), '120,000'),
        line(d('expTransport'), '260,000'),
        sub(d('debts')),
        line(d('debtAli'), '50,000', accent: true),
        line(d('debtNoor'), '400,000', accent: true),
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
  String kind = 'Product';
  String product = '',
      qty = '1',
      price = '',
      supplier = '',
      date = '2026-09-27',
      notes = '';
  int version = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final ar = app.lang == 'ar';
    final total = (int.tryParse(price) ?? 0) * (int.tryParse(qty) ?? 1);
    return _sectionBody([
      Text(
        ar ? 'انشاء طلبية / Create Order' : 'Create Order / انشاء طلبية',
        style: ts(context, 16, weight: w700),
      ),
      Row(
        children: [
          for (final k in const ['Product', 'Lab']) ...[
            if (k == 'Lab') const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => kind = k),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kind == k ? pal.accent : pal.chipBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    k == 'Product'
                        ? (ar
                              ? 'منتج / جهاز / مستهلك'
                              : 'Product / Device / Consumable')
                        : (ar ? 'مختبر للبيع' : 'Lab for Sale'),
                    textAlign: TextAlign.center,
                    style: ts(
                      context,
                      13,
                      weight: w700,
                      color: kind == k ? Colors.white : pal.muted2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      _Field(
        key: ValueKey('p-$version'),
        label: ar ? 'المنتج / المختبر' : 'Product / Lab',
        initial: product,
        hint: kind == 'Lab' ? 'Lab name' : 'Centrifuge',
        fontSize: 14,
        onChanged: (v) => product = v,
      ),
      Row(
        children: [
          Expanded(
            child: _Field(
              key: ValueKey('q-$version'),
              label: ar ? 'الكمية' : 'Quantity',
              initial: qty,
              fontSize: 14,
              keyboard: TextInputType.number,
              onChanged: (v) => setState(() => qty = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Field(
              key: ValueKey('pr-$version'),
              label: ar ? 'السعر (د.ع)' : 'Price (IQD)',
              initial: price,
              fontSize: 14,
              keyboard: TextInputType.number,
              onChanged: (v) => setState(() => price = v),
            ),
          ),
        ],
      ),
      _Field(
        key: ValueKey('s-$version'),
        label: ar ? 'المورد / المختبر' : 'Supplier / Lab',
        initial: supplier,
        hint: 'Al-Noor Lab',
        fontSize: 14,
        onChanged: (v) => supplier = v,
      ),
      _Field(
        key: ValueKey('d-$version'),
        label: ar ? 'تاريخ التوصيل' : 'Delivery date',
        initial: date,
        fontSize: 14,
        keyboard: TextInputType.datetime,
        onChanged: (v) => date = v,
      ),
      _Field(
        key: ValueKey('n-$version'),
        label: ar ? 'ملاحظات' : 'Notes',
        initial: notes,
        fontSize: 14,
        lines: 2,
        onChanged: (v) => notes = v,
      ),
      Text(
        '${ar ? 'الإجمالي' : 'Total'}: ${formatNumber(total)} IQD',
        style: ts(context, 13, weight: w700),
      ),
      _pill(
        context,
        ar ? 'إنشاء الطلبية' : 'Create Order',
        color: pal.accent,
        textColor: Colors.white,
        onTap: () {
          final now = DateTime.now();
          final q = math.max(1, int.tryParse(qty) ?? 1);
          final p = int.tryParse(price) ?? 0;
          app.addProductOrder(
            ProductOrder(
              id: '${now.microsecondsSinceEpoch}',
              productName: product.trim().isNotEmpty
                  ? product.trim()
                  : (kind == 'Lab' ? 'Lab for Sale' : 'Product'),
              code: kind == 'Lab' ? 'LAB-ORDER' : 'CO-ORDER',
              price: p,
              quantity: q,
              total: p * q,
              address: app.userAddress,
              phone: app.userPhone,
              createdAt:
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
            ),
          );
          setState(() {
            product = '';
            qty = '1';
            price = '';
            supplier = '';
            notes = '';
            version++;
          });
        },
      ),
      _pill(
        context,
        '${ar ? 'طلباتي' : 'My Orders'} (${app.productOrders.length})',
        color: pal.chipBg,
        border: pal.cardBorder,
        onTap: () => app.toast(
          app.tr(
            'المتجر يأتي في الدفعة القادمة',
            'فرۆشگا لە بەشی داهاتوودا دێت',
            'The store arrives in the next batch',
          ),
        ),
      ),
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
              info(d('developerLabel'), 'LabGo Team'),
              const SizedBox(height: 8),
              info(d('contactLabel'), '+964 770 123 4567', ltr: true),
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
                      onTap: () => app.toast(d('privacyLabel')),
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
                      onTap: () => app.toast(d('termsLabel')),
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

class _ReportsState extends State<_Reports> {
  bool editLab = false;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final d = app.d, w = app.w;
    final ink = pal.dark ? Colors.white : const Color(0xFF111111);
    final grey = pal.dark ? const Color(0xFFA1A1AA) : const Color(0xFF666666);

    Widget preview(
      String line, {
      bool dashed = false,
      bool footerPhone = true,
    }) {
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: pal.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Fixed.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'L',
                    style: ts(context, 16, weight: w900, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.labName,
                        style: ts(context, 16, weight: w700, color: ink),
                      ),
                      Text(
                        '${d('licensedBy')}: ${app.licenseOwners}',
                        style: ts(context, 10, color: grey),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${app.labPhone}\n${app.labAddress}',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.ltr,
                  style: ts(context, 10, color: grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(line, style: ts(context, 12, color: ink)),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: pal.line)),
            ),
            child: Text(
              '${app.labFooter} • ${app.labAddress}${footerPhone ? ' • ${app.labPhone}' : ''}',
              textAlign: TextAlign.center,
              style: ts(context, 10, color: grey),
            ),
          ),
        ],
      );
      final box = Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: pal.white,
          borderRadius: BorderRadius.circular(16),
          border: dashed ? null : Border.all(color: pal.line),
        ),
        child: content,
      );
      return dashed
          ? CustomPaint(foregroundPainter: _Dashed(pal.line), child: box)
          : box;
    }

    return _sectionBody([
      _pill(
        context,
        d('editLabData'),
        color: pal.accent,
        textColor: Colors.white,
        onTap: () => setState(() => editLab = !editLab),
      ),
      if (editLab) const LabDataCard(inner: true),
      Text(d('headerFooter'), style: ts(context, 14, weight: w700)),
      _LogoButton(label: '${d('logoLabel')} — LabGo', toastName: 'LabGo'),
      _Field(
        label: d('phoneLabel'),
        initial: app.labPhone,
        ltr: true,
        fontSize: 14,
        vPad: 10,
        onChanged: (v) => app.updateSettings(() => app.labPhone = v),
      ),
      _Field(
        label: d('addressLabel'),
        initial: app.labAddress,
        fontSize: 14,
        vPad: 10,
        onChanged: (v) => app.updateSettings(() => app.labAddress = v),
      ),
      _Field(
        label: d('footerLabel'),
        initial: app.labFooter,
        fontSize: 14,
        vPad: 10,
        onChanged: (v) => app.updateSettings(() => app.labFooter = v),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(d('resultPreview'), style: ts(context, 13, weight: w700)),
          preview('CBC • 13.2 g/dL • ${w('normal')}'),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(d('receiptPreview'), style: ts(context, 13, weight: w700)),
          preview(
            'Ali Ahmed • CBC • 25,000 IQD • ${w('payLater')}',
            dashed: true,
            footerPhone: false,
          ),
        ],
      ),
      Text(w('templates'), style: ts(context, 13, weight: w700)),
      for (final tpl in app.templates)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.chipBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tpl.$1 == 'standard'
                      ? w('standard')
                      : tpl.$1 == 'hormonePanel'
                      ? w('hormonePanel')
                      : w('urgentReport'),
                  style: ts(context, 14, weight: w700),
                ),
              ),
              GestureDetector(
                onTap: () => app.toast(w('templateSaved')),
                child: Text(
                  w('editTemplate'),
                  style: ts(context, 12, weight: w700, color: pal.accent),
                ),
              ),
              const SizedBox(width: 8),
              Toggle(
                value: tpl.$2,
                onTap: () => app.updateSettings(
                  () => app.templates = [
                    for (final x in app.templates)
                      x.$1 == tpl.$1 ? (x.$1, !x.$2) : x,
                  ],
                ),
              ),
            ],
          ),
        ),
      Text(
        '${w('statuses')}: ${w('completed')} • ${w('pending')} • ${w('sent')}',
        style: ts(context, 12, color: pal.muted),
      ),
    ]);
  }
}

class _Dashed extends CustomPainter {
  final Color color;
  _Dashed(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (const Offset(0, 4) & Size(size.width, size.height - 4)).deflate(.5),
          const Radius.circular(16),
        ),
      );
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 6) {
        canvas.drawPath(m.extractPath(d, math.min(d + 3, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Dashed old) => old.color != color;
}

/// Logo tile "L+n" (design: logo button; tapping bumps the counter).
class _LogoButton extends StatelessWidget {
  final String label;
  final String toastName;
  const _LogoButton({required this.label, required this.toastName});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    return GestureDetector(
      onTap: () {
        app.updateSettings(() => app.logoBumps++);
        app.toast('${app.d('logoLabel')} • $toastName');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: pal.chipBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pal.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'L${app.logoBumps > 0 ? '+${app.logoBumps}' : ''}',
                style: ts(context, 22, weight: w900, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: ts(context, 13, weight: w700)),
                  Text(
                    app.d('logoHint'),
                    style: ts(context, 11, color: pal.muted),
                  ),
                ],
              ),
            ),
            LIcon('Pencil', size: 14, color: pal.muted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lab data (design `Md`)

class LabDataCard extends StatelessWidget {
  final bool inner;
  const LabDataCard({super.key, this.inner = false});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final d = app.d, w = app.w;
    final note = app.tr(
      'رفع الصور من الاستوديو غير متاح بعد',
      'بەرزکردنەوە لە ستۆدیۆ هێشتا بەردەست نییە',
      'Photo uploads from Studio are not available yet',
    );
    final card = CardBox(
      child: _col([
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.chipBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 100,
                height: 100,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: pal.cardBorder),
                ),
                child: Image.asset(
                  'assets/images/logo.jpg',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.tr('صورة المختبر', 'وێنەی تاقیگە', 'Lab Image'),
                      style: ts(context, 14, weight: w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: ts(context, 11, color: pal.muted, height: 1.375),
                    ),
                    const SizedBox(height: 8),
                    _pill(
                      context,
                      app.tr(
                        'تغيير صورة المختبر',
                        'گۆڕینی وێنەی تاقیگە',
                        'Change Lab Image',
                      ),
                      onTap: () => app.toast(note),
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
        _LogoButton(
          label: '${d('logoLabel')} — ${app.labName}',
          toastName: app.labName,
        ),
        _Field(
          label: d('labNameLabel'),
          initial: app.labName,
          hint: 'LabGo',
          fontSize: 14,
          onChanged: (v) => app.updateSettings(() => app.labName = v),
        ),
        _Field(
          label: d('licenseOwnersLabel'),
          initial: app.licenseOwners,
          hint: d('licenseOwnersPh'),
          fontSize: 14,
          lines: 3,
          onChanged: (v) => app.updateSettings(() => app.licenseOwners = v),
        ),
        _Field(
          label: d('phoneLabel'),
          initial: app.labPhone,
          ltr: true,
          fontSize: 14,
          onChanged: (v) => app.updateSettings(() => app.labPhone = v),
        ),
        _Field(
          label: d('addressLabel'),
          initial: app.labAddress,
          fontSize: 14,
          onChanged: (v) => app.updateSettings(() => app.labAddress = v),
        ),
        _Field(
          label: d('footerLabel'),
          initial: app.labFooter,
          fontSize: 14,
          onChanged: (v) => app.updateSettings(() => app.labFooter = v),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pal.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: pal.line)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Fixed.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'L',
                        style: ts(
                          context,
                          16,
                          weight: w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.labName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ts(context, 16, weight: w700),
                          ),
                          Text(
                            '${d('licensedBy')}: ${app.licenseOwners}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ts(context, 10, color: pal.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${app.labPhone}\n${app.labAddress}',
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.ltr,
                      style: ts(context, 10, color: pal.muted),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: pal.line)),
                ),
                child: Text(
                  '${app.labFooter} • ${app.labAddress} • ${app.labPhone}',
                  textAlign: TextAlign.center,
                  style: ts(context, 10, color: pal.muted),
                ),
              ),
            ],
          ),
        ),
        _pill(
          context,
          w('save'),
          color: pal.accent,
          textColor: Colors.white,
          onTap: () => app.toast(w('saved')),
        ),
      ]),
    );
    return Padding(
      padding: EdgeInsets.only(top: inner ? 0 : 12),
      child: Entrance.pop(child: card),
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
  String type = 'Sharps',
      weight = '',
      date = '2026-09-27',
      driver = '',
      status = 'Pending',
      notes = '';
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

    String statusText(String s) => s == 'Pending'
        ? w('pending')
        : s == 'Completed'
        ? w('completed')
        : s;
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
                hint: '1.2',
                fontSize: 14,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => weight = v,
              ),
              _Field(
                key: ValueKey('dt-$version'),
                label: d('pickupDate'),
                initial: date,
                fontSize: 14,
                keyboard: TextInputType.datetime,
                onChanged: (v) => date = v,
              ),
              _Field(
                key: ValueKey('dr-$version'),
                label: d('driverCompany'),
                initial: driver,
                hint: 'Al-Noor Waste Co.',
                fontSize: 14,
                onChanged: (v) => driver = v,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d('transferStatus'),
                    style: ts(context, 12, weight: w700, color: pal.muted),
                  ),
                  const SizedBox(height: 4),
                  chips(
                    [
                      ('Pending', w('pending')),
                      ('In Transit', 'In Transit'),
                      ('Completed', w('completed')),
                    ],
                    status,
                    (v) => setState(() => status = v),
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
                  app.addWasteTransfer(
                    WasteTransfer(
                      id: '${DateTime.now().microsecondsSinceEpoch}',
                      date: date.isNotEmpty ? date : '2026-09-27',
                      type: type,
                      weight: kg,
                      status: status,
                      driver: driver.trim().isNotEmpty
                          ? driver.trim()
                          : 'Al-Noor Waste Co.',
                      notes: notes,
                    ),
                  );
                  setState(() {
                    weight = '';
                    notes = '';
                    driver = '';
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
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: t.type,
                                style: const TextStyle(fontWeight: w700),
                              ),
                              TextSpan(text: ' • ${t.date}'),
                            ],
                          ),
                          style: ts(context, 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: t.status == 'Pending'
                              ? pal.softAccent
                              : pal.chipBg,
                          borderRadius: BorderRadius.circular(999),
                          border: t.status == 'Pending'
                              ? null
                              : Border.all(color: pal.line),
                        ),
                        child: Text(
                          statusText(t.status),
                          style: ts(
                            context,
                            11,
                            weight: w700,
                            color: t.status == 'Pending'
                                ? pal.accent
                                : pal.muted2,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${fmtWeight(t.weight)} ${w('kg')} • ${d('driverCompany')}: ${t.driver}',
                    style: ts(context, 13, color: pal.muted2),
                  ),
                  if (t.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(t.notes, style: ts(context, 12, color: pal.muted)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
