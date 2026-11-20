import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../ui.dart';
import 'settings_screen.dart' show showTermsPage;

/// Login / Register / OTP / Forgot / Reset — the design's pre-app flow.
class AuthBody extends StatelessWidget {
  const AuthBody({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    Widget screen;
    switch (app.auth) {
      case 'register':
        screen = const _Register();
      case 'otp':
        screen = const _Otp();
      case 'forgot':
        screen = const _Forgot();
      case 'reset':
        screen = const _Reset();
      default:
        screen = const _Login();
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (app.authBanner != null)
            _Banner(text: app.authBanner!, color: Fixed.green),
          Entrance(key: ValueKey('${app.auth}-${app.lang}'), child: screen),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: ts(context, 13, weight: w700, color: Colors.white),
    ),
  );
}

// ---------------------------------------------------------------------------
// shared pieces

/// Round logo + "LabGo" + tagline + welcome line.
class _LogoHeader extends StatelessWidget {
  final double titleSize;
  const _LogoHeader({this.titleSize = 32});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: pal.cardBorder),
              boxShadow: Shadows.logo,
            ),
            child: Image.asset(
              'assets/images/logo.jpg',
              width: 78,
              height: 78,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'LabGo',
            style: ts(context, titleSize, weight: w900, height: 1.25),
          ),
          const SizedBox(height: 4),
          Text(
            app.tr(
              'مختبرك بين يديك',
              'تاقیگەکەت لە دەستتدا',
              'Your Lab in Your Hands',
            ),
            textAlign: TextAlign.center,
            style: ts(context, 15, weight: w700),
          ),
          const SizedBox(height: 4),
          Text(
            app.p('welcomeSub'),
            textAlign: TextAlign.center,
            style: ts(context, 14, color: pal.muted),
          ),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: ts(context, 12, weight: w700, color: context.pal.muted),
  );
}

/// `w-full bg-[var(--input-bg)] rounded-2xl px-3 py-3.5 text-[15px] border border-[var(--card-border)]`
class AuthInput extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool obscure;
  final double startPad;
  final double endPad;
  final Widget? start;
  final Widget? end;
  final TextInputType? keyboard;
  final bool forceLtr;
  final List<TextInputFormatter>? formatters;
  final double vPad;
  final double fontSize;

  const AuthInput({
    super.key,
    this.controller,
    this.focusNode,
    required this.hint,
    this.onChanged,
    this.obscure = false,
    this.startPad = 12,
    this.endPad = 12,
    this.start,
    this.end,
    this.keyboard,
    this.forceLtr = false,
    this.formatters,
    this.vPad = 14,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final rtl = app.rtl;
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      obscureText: obscure,
      keyboardType: keyboard,
      inputFormatters: formatters,
      textDirection: forceLtr ? TextDirection.ltr : null,
      textAlign: forceLtr && rtl ? TextAlign.left : TextAlign.start,
      textAlignVertical: TextAlignVertical.center,
      style: ts(context, fontSize, height: 1.5),
      strutStyle: StrutStyle(
        fontSize: fontSize,
        height: 1.5,
        forceStrutHeight: true,
      ),
      cursorColor: pal.accent,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        hintTextDirection: forceLtr ? TextDirection.ltr : null,
        hintStyle: ts(context, fontSize, color: pal.placeholder, height: 1.5),
        contentPadding: EdgeInsetsDirectional.only(
          start: startPad,
          end: endPad,
        ),
      ),
    );
    // CSS box: line-height (1.5) + vertical padding + 1px border top and bottom.
    final height = fontSize * 1.5 + vPad * 2 + 2;
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // The box is drawn here so its size never depends on font metrics.
        Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pal.inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pal.cardBorder),
          ),
          child: field,
        ),
        if (start != null)
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Center(child: start!),
          ),
        if (end != null)
          PositionedDirectional(
            end: 0,
            top: 0,
            bottom: 0,
            child: Center(child: end!),
          ),
      ],
    );
  }
}

/// Icon slot `w-9 h-9 grid place-items-center` offset 6px from the edge.
class _IconSlot extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _IconSlot({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(width: 36, height: 36, child: Center(child: child)),
    ),
  );
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final bool withLeadingIcon;
  const _PasswordField({
    required this.controller,
    this.withLeadingIcon = false,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return AuthInput(
      controller: widget.controller,
      hint: '••••••••',
      obscure: !_show,
      startPad: widget.withLeadingIcon ? 42 : 12,
      endPad: 44,
      start: widget.withLeadingIcon
          ? _IconSlot(child: LIcon('FileText', size: 17, color: pal.muted))
          : null,
      end: _IconSlot(
        onTap: () => setState(() => _show = !_show),
        child: LIcon(_show ? 'EyeOff' : 'Eye', size: 18, color: pal.muted),
      ),
    );
  }
}

/// Phone input with the "+964" prefix (paddingInlineStart 92).
class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _PhoneField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return AuthInput(
      controller: controller,
      hint: '770 123 4567',
      onChanged: onChanged,
      keyboard: TextInputType.phone,
      forceLtr: true,
      startPad: 92,
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s]'))],
      start: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LIcon('Phone', size: 17, color: pal.muted),
            const SizedBox(width: 6),
            Text(
              '+964',
              textDirection: TextDirection.ltr,
              style: ts(context, 14, weight: w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _EmailField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) => AuthInput(
    controller: controller,
    hint: 'example@email.com',
    onChanged: onChanged,
    keyboard: TextInputType.emailAddress,
    forceLtr: true,
    startPad: 42,
    start: _IconSlot(child: LIcon('Mail', size: 17, color: context.pal.muted)),
  );
}

/// Phone / Email segmented control.
class _Segmented extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _Segmented({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    Widget tab(String id, String label) => Expanded(
      child: Tap(
        onTap: () => onChanged(id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: value == id ? pal.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: ts(
              context,
              14,
              weight: w700,
              color: value == id ? Colors.white : pal.muted2,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pal.segmented,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          tab('phone', app.tr('رقم الهاتف', 'ژمارەی تەلەفۆن', 'Phone Number')),
          const SizedBox(width: 4),
          tab('email', app.tr('الإيميل', 'ئیمەیڵ', 'Email')),
        ],
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  final bool checked;
  const _Checkbox(this.checked);

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? pal.accent : pal.inputBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: checked ? pal.accent : pal.line),
      ),
      child: checked
          ? const LIcon('Check', size: 14, color: Colors.white)
          : null,
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String text;
  final double top;
  const _ErrorText(this.text, {this.top = 0});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top),
    child: Text(
      text,
      style: ts(context, 13, weight: w700, color: Fixed.red),
    ),
  );
}

/// Gradient primary button (`linear-gradient(135deg,#FF5A00,#FF8A3D)`).
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final bool shadow;
  final bool arrow;
  final Gradient? gradient;

  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 52,
    this.radius = 16,
    this.shadow = false,
    this.arrow = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = context.app.rtl;
    return Tap(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient ?? context.pal.accentGradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: context.pal.accentShadow,
                    offset: Offset(0, 10),
                    blurRadius: 24,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: ts(context, 16, weight: w700, color: Colors.white),
            ),
            if (arrow) ...[
              const SizedBox(width: 8),
              // design: ArrowLeft flipped in LTR so it points forward
              LIcon('ArrowLeft', size: 18, color: Colors.white, flipX: !rtl),
            ],
          ],
        ),
      ),
    );
  }
}

/// Solid / outlined / muted block buttons used on auth screens.
class BlockButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Color? textColor;
  final Color? borderColor;
  final double radius;
  final double vPad;
  final double fontSize;

  const BlockButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.textColor,
    this.borderColor,
    this.radius = 16,
    this.vPad = 14,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(
        vertical: vPad - (borderColor != null ? 2 : 0),
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 2)
            : null,
      ),
      child: Text(
        label,
        style: ts(
          context,
          fontSize,
          weight: w700,
          color: textColor ?? context.pal.ink,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Login

class _Login extends StatefulWidget {
  const _Login();

  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final _pass = TextEditingController();

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    _phone = TextEditingController(text: app.loginPhone);
    _email = TextEditingController(text: app.loginEmail);
  }

  bool _remember = false;
  String _error = '';

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final method = app.loginMethod;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _LogoHeader(),
        // header mb-2 and card mt-4 collapse into one 16px gap in CSS
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: pal.cardBorder),
            boxShadow: Shadows.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Segmented(
                value: method,
                onChanged: (v) => setState(() => app.loginMethod = v),
              ),
              const SizedBox(height: 12),
              FieldLabel(
                method == 'phone'
                    ? app.tr('رقم الهاتف', 'ژمارەی تەلەفۆن', 'Phone Number')
                    : app.tr('الإيميل', 'ئیمەیڵ', 'Email'),
              ),
              const SizedBox(height: 4),
              method == 'phone'
                  ? _PhoneField(
                      controller: _phone,
                      onChanged: (v) => app.loginPhone = v,
                    )
                  : _EmailField(
                      controller: _email,
                      onChanged: (v) => app.loginEmail = v,
                    ),
              const SizedBox(height: 14),
              FieldLabel(app.p('password')),
              const SizedBox(height: 4),
              _PasswordField(controller: _pass, withLeadingIcon: true),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ErrorText(_error),
              ],
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _remember = !_remember),
                      child: Row(
                        children: [
                          _Checkbox(_remember),
                          const SizedBox(width: 8),
                          Text(
                            app.tr('تذكرني', 'بمبیربهێنەرەوە', 'Remember me'),
                            style: ts(context, 13, weight: w700),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        app.forgotMethod = method;
                        app.forgotPhone = _phone.text;
                        app.forgotEmail = _email.text;
                        app.goAuth('forgot');
                      },
                      child: Text(
                        app.p('forgot'),
                        style: ts(context, 13, weight: w700, color: pal.accent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GradientButton(
                label: app.p('loginBtn'),
                arrow: true,
                shadow: true,
                onTap: () {
                  final id = method == 'phone'
                      ? _phone.text.trim()
                      : _email.text.trim();
                  if (id.isEmpty || _pass.text.isEmpty) {
                    setState(() => _error = app.p('fillAll'));
                    return;
                  }
                  setState(() => _error = '');
                  app.signIn(
                    id,
                    _pass.text,
                    onError: (msg) {
                      if (mounted) setState(() => _error = msg);
                    },
                  );
                },
              ),
              const SizedBox(height: 14),
              BlockButton(
                label: app.tr(
                  'تصفح كضيف',
                  'وەک میوان گەڕان',
                  'Browse as Guest',
                ),
                textColor: pal.accent,
                borderColor: pal.accent,
                onTap: () => app.enterApp(asGuest: true),
              ),
              const SizedBox(height: 14),
              BlockButton(
                label: app.p('createLink'),
                color: pal.segmented,
                onTap: () => app.goAuth('register'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'LabGo © 2026 - ${app.tr('جميع الحقوق محفوظة', 'هەموو مافەکان پارێزراون', 'All rights reserved')} • v1.0',
          textAlign: TextAlign.center,
          style: ts(context, 11, color: pal.muted),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Register (2 steps)

class _Register extends StatefulWidget {
  const _Register();

  @override
  State<_Register> createState() => _RegisterState();
}

class _RegisterState extends State<_Register> {
  int _step = 1;
  final _name = TextEditingController();
  final _lab = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _cert = TextEditingController();
  final _idFront = TextEditingController();
  final _idBack = TextEditingController();
  final _city = TextEditingController();
  bool _terms = false;
  String _error = '';
  /// Picked documents: (file name, bytes).
  (String, Uint8List)? _certFile, _idFrontFile, _idBackFile;

  /// Asks where the document comes from (camera, photos or files), then picks it.
  Future<(String, Uint8List)?> _pick() async {
    final app = context.app;
    final pal = context.pal;
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: pal.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in [
                ('camera', 'Camera', app.tr('الكاميرا', 'کامێرا', 'Camera')),
                ('gallery', 'Image', app.tr('صورة من الاستوديو', 'وێنە لە گەلەری', 'Photo library')),
                ('files', 'FileText', app.tr('ملف (PDF أو صورة)', 'فایل', 'File (PDF or image)')),
              ])
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Tap(
                    onTap: () => Navigator.pop(ctx, o.$1),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        LIcon(o.$2, size: 18, color: pal.ink),
                        const SizedBox(width: 10),
                        Text(o.$3, style: ts(ctx, 14, weight: w700)),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return null;
    try {
      if (source == 'files') {
        final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png']);
        if (picked.isEmpty) return null;
        final f = picked.first;
        return (f.name, await f.readAsBytes());
      }
      final f = await ImagePicker().pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2200, maxHeight: 2200, imageQuality: 85,
      );
      if (f == null) return null;
      final name = f.name.isEmpty || !f.name.contains('.') ? 'document.jpg' : f.name;
      return (name, await f.readAsBytes());
    } catch (_) {
      if (mounted) {
        setState(() => _error = source == 'camera'
            ? app.tr('تعذر فتح الكاميرا. اسمح للتطبيق من الإعدادات.', 'کامێرا ناکرێتەوە.', 'Cannot open the camera. Allow access in Settings.')
            : app.tr('تعذر فتح الملف', 'فایل ناکرێتەوە', 'Cannot open the file'));
      }
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    void clear() {
      if (_error.isNotEmpty && mounted) setState(() => _error = '');
    }
    _pass.addListener(clear);
    _confirm.addListener(clear);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _lab,
      _phone,
      _email,
      _pass,
      _confirm,
      _cert,
      _idFront,
      _idBack,
      _city,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _labeled(String label, Widget input) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [FieldLabel(label), const SizedBox(height: 4), input],
  );

  Widget _stepDot(int n, String label) {
    final pal = context.pal;
    final active = _step == n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? pal.accent : pal.chipBg,
            shape: BoxShape.circle,
            border: active ? null : Border.all(color: pal.cardBorder),
          ),
          child: Text(
            '$n',
            style: ts(
              context,
              13,
              weight: w900,
              color: active ? Colors.white : pal.muted2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: ts(context, 12, weight: w700)),
      ],
    );
  }

  Widget _uploadBox({
    required String icon,
    required String title,
    required String sub,
    required (String, Uint8List)? file,
    required ValueChanged<(String, Uint8List)> onPicked,
  }) {
    final pal = context.pal;
    if (file != null) {
      icon = 'CircleCheck';
      title = file.$1;
      sub = context.app.tr('تم الاختيار — اضغط للتغيير', 'هەڵبژێردرا', 'Chosen — tap to change');
    }
    return Tap(
      onTap: () async {
        final f = await _pick();
        if (f != null) onPicked(f);
      },
      child: CustomPaint(
        painter: _DashedBorder(color: pal.line, radius: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: pal.chipBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pal.chipBg,
                  shape: BoxShape.circle,
                ),
                child: LIcon(icon, size: 22, color: pal.muted),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: ts(context, 13, weight: w700),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: ts(context, 11, color: pal.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final t = app.tr;
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              app.p('createTitle'),
              style: ts(context, 26, weight: w900, height: 1.25),
            ),
            const SizedBox(height: 4),
            Text(app.p('createSub'), style: ts(context, 14, color: pal.muted)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          _stepDot(1, t('البيانات', 'زانیاری', 'Details')),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: _step == 2 ? pal.accent : pal.track,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _stepDot(2, t('المستندات', 'بەڵگەنامەکان', 'Documents')),
        ],
      ),
      const SizedBox(height: 20),
    ];

    if (_step == 1) {
      Widget eye(TextEditingController c) => _PasswordField(controller: c);
      children.addAll(
        _spaced([
          _labeled(
            app.p('fullName'),
            AuthInput(controller: _name, hint: 'Dr. Ahmed'),
          ),
          _labeled(
            app.p('labName'),
            AuthInput(controller: _lab, hint: 'LabGo Mosul'),
          ),
          _labeled(
            app.p('phone'),
            AuthInput(
              controller: _phone,
              hint: '+964 770 000 0000',
              forceLtr: true,
              keyboard: TextInputType.phone,
            ),
          ),
          _labeled(
            app.p('email'),
            AuthInput(
              controller: _email,
              hint: 'name@mail.com',
              forceLtr: true,
              keyboard: TextInputType.emailAddress,
            ),
          ),
          _labeled(
            app.tr('المدينة', 'شار', 'City'),
            AuthInput(controller: _city, hint: app.tr('مثلاً: بغداد', 'بۆ نموونە: بەغدا', 'e.g. Baghdad')),
          ),
          _labeled(app.p('password'), eye(_pass)),
          _labeled(app.p('confirmPass'), eye(_confirm)),
          GestureDetector(
            onTap: () => setState(() => _terms = !_terms),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _Checkbox(_terms),
                ),
                const SizedBox(width: 8),
                // Tapping the words opens the terms; the box ticks them.
                Expanded(
                  child: GestureDetector(
                    onTap: () => showTermsPage(context),
                    child: Text(
                      app.p('terms'),
                      style: ts(context, 13, weight: w600, color: context.pal.accent).copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: context.pal.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error.isNotEmpty) _ErrorText(_error),
          GradientButton(
            label: t('التالي', 'دواتر', 'Next'),
            arrow: true,
            height: 56,
            onTap: () {
              if ([
                    _name,
                    _lab,
                    _phone,
                    _email,
                    _city,
                  ].any((c) => c.text.trim().isEmpty) ||
                  _pass.text.isEmpty ||
                  _confirm.text.isEmpty) {
                setState(() => _error = app.p('fillAll'));
                return;
              }
              if (_pass.text != _confirm.text) {
                setState(() => _error = app.p('passMismatch'));
                return;
              }
              if (_pass.text.length < 8) {
                setState(() => _error = app.tr('كلمة المرور 8 أحرف على الأقل', 'وشەی نهێنی لانیکەم ٨ پیت', 'Password must be at least 8 characters'));
                return;
              }
              if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(_email.text.trim())) {
                setState(() => _error = app.tr('أدخل بريداً صحيحاً', 'ئیمەیڵێکی دروست بنووسە', 'Enter a valid email'));
                return;
              }
              if (!_terms) {
                setState(() => _error = app.p('needTerms'));
                return;
              }
              setState(() {
                _error = '';
                _step = 2;
              });
            },
          ),
        ], 12),
      );
    } else {
      Widget docCard(List<Widget> kids) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: pal.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _spaced(kids, 12),
        ),
      );
      children.addAll(
        _spaced([
          Text(
            t('رفع المستندات', 'بەرزکردنەوەی بەڵگەنامەکان', 'Upload Documents'),
            style: ts(context, 18, weight: w900, height: 1.25),
          ),
          Text(
            t(
              'شهادة فتح المختبر والهوية الوطنية',
              'بڕوانامەی کردنەوەی تاقیگە و ناسنامەی نیشتمانی',
              'Lab opening certificate and national ID',
            ),
            style: ts(context, 13, color: pal.muted),
          ),
          docCard([
            Text(
              t(
                'شهادة فتح المختبر',
                'بڕوانامەی کردنەوەی تاقیگە',
                'Lab Opening Certificate',
              ),
              style: ts(context, 14, weight: w700),
            ),
            _uploadBox(
              icon: 'FileText',
              title: t('اضغط للرفع', 'بۆ بەرزکردنەوە بکە', 'Tap to upload'),
              sub: t('صورة / PDF', 'وێنە / PDF', 'Image / PDF'),
              file: _certFile,
              onPicked: (f) => setState(() => _certFile = f),
            ),

          ]),
          docCard([
            Text(
              t('الهوية الوطنية', 'ناسنامەی نیشتمانی', 'National ID'),
              style: ts(context, 14, weight: w700),
            ),
            _uploadBox(
              icon: 'User',
              title: t(
                'الوجه الأمامي — اضغط للرفع',
                'ڕووی پێشەوە — بۆ بەرزکردنەوە بکە',
                'Front side — Tap to upload',
              ),
              sub: t('صورة / PDF', 'وێنە / PDF', 'Image / PDF'),
              file: _idFrontFile,
              onPicked: (f) => setState(() => _idFrontFile = f),
            ),
            _uploadBox(
              icon: 'User',
              title: t(
                'الوجه الخلفي — اضغط للرفع',
                'ڕووی دواوە — بۆ بەرزکردنەوە بکە',
                'Back side — Tap to upload',
              ),
              sub: t('صورة / PDF', 'وێنە / PDF', 'Image / PDF'),
              file: _idBackFile,
              onPicked: (f) => setState(() => _idBackFile = f),
            ),
          ]),
          Text(
            t(
              'سيتم مراجعة المستندات خلال 24 ساعة',
              'بەڵگەنامەکان لە ماوەی ٢٤ کاتژمێردا پێداچوونەوەیان بۆ دەکرێت',
              'Documents will be reviewed within 24 hours',
            ),
            textAlign: TextAlign.center,
            style: ts(context, 12, color: pal.muted),
          ),
          if (_error.isNotEmpty) _ErrorText(_error),
          Row(
            children: [
              Expanded(
                child: BlockButton(
                  label: t('السابق', 'پێشتر', 'Previous'),
                  color: pal.segmented,
                  radius: 999,
                  vPad: 16,
                  onTap: () => setState(() {
                    _error = '';
                    _step = 1;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: GradientButton(
                  label: app.authBusy ? '…' : app.p('createBtn'),
                  radius: 999,
                  height: 56,
                  onTap: () async {
                    if (app.authBusy) return;
                    if (_certFile == null) {
                      setState(() => _error = t('ارفع شهادة فتح المختبر', 'بڕوانامە بار بکە', 'Upload the lab opening certificate'));
                      return;
                    }
                    if (_idFrontFile == null || _idBackFile == null) {
                      setState(() => _error = t('ارفع وجهي الهوية الوطنية', 'هەردوو ڕووی ناسنامە بار بکە', 'Upload both sides of the national ID'));
                      return;
                    }
                    final err = await app.startRegistration({
                      'ownerName': _name.text.trim(),
                      'labName': _lab.text.trim(),
                      'phone': _phone.text.trim(),
                      'email': _email.text.trim(),
                      'password': _pass.text,
                      'city': _city.text.trim(),
                    }, [
                      ('labOpeningLicense', _certFile!.$1, _certFile!.$2),
                      ('ownerUnifiedCard', _idFrontFile!.$1, _idFrontFile!.$2),
                      ('ownerUnifiedCard', _idBackFile!.$1, _idBackFile!.$2),
                    ]);
                    if (err != null && mounted) setState(() => _error = err);
                  },
                ),
              ),
            ],
          ),
        ], 12),
      );
    }

    children.addAll([
      const SizedBox(height: 16),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${app.p('haveAccount')} ',
            style: ts(context, 13, color: pal.muted),
          ),
          GestureDetector(
            onTap: () => app.goAuth('login'),
            child: Text(
              app.p('loginLink'),
              style: ts(context, 13, weight: w900, color: pal.accent),
            ),
          ),
        ],
      ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

List<Widget> _spaced(List<Widget> items, double gap) => [
  for (var i = 0; i < items.length; i++) ...[
    if (i > 0) SizedBox(height: gap),
    items[i],
  ],
];

class _DashedBorder extends CustomPainter {
  final Color color;
  final double radius;
  _DashedBorder({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(1);
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 6, metric.length)),
          paint,
        );
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorder old) => old.color != color;
}

// ---------------------------------------------------------------------------
// OTP

class _Otp extends StatefulWidget {
  const _Otp();

  @override
  State<_Otp> createState() => _OtpState();
}

class _OtpState extends State<_Otp> with SingleTickerProviderStateMixin {
  final _ctrls = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());
  String _status = 'idle'; // idle | wrong | correct
  String _error = '';
  int _seconds = 60;
  Timer? _timer;
  late final AnimationController _anim = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds = _seconds > 0 ? _seconds - 1 : 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _setStatus(String s) {
    _status = s;
    if (s == 'wrong') {
      _anim.duration = const Duration(milliseconds: 400);
      _anim.forward(from: 0);
    } else if (s == 'correct') {
      _anim.duration = const Duration(milliseconds: 550);
      _anim.forward(from: 0);
    }
  }

  void _confirm() {
    final app = context.app;
    if (_ctrls.any((c) => c.text.isEmpty)) {
      setState(() => _error = app.p('fillOtp'));
      return;
    }
    if (app.authBusy) return;
    app.confirmOtp(_ctrls.map((c) => c.text).join()).then((err) {
      if (!mounted) return;
      if (err == null) {
        setState(() {
          _setStatus('correct');
          _error = '';
        });
        Timer(const Duration(milliseconds: 650), () {
          if (app.otpPurpose == 'forgot') {
            app.goAuth('reset');
          } else if (LabApi.enabled) {
            app.goAuth('login'); // the lab waits for LabGo to activate it
          } else {
            app.enterApp();
          }
        });
      } else {
        setState(() {
          _setStatus('wrong');
          _error = err;
        });
      }
    });
  }

  void _onDigit(int i, String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      // paste support
      for (var k = 0; k < 6; k++) {
        _ctrls[k].text = k < digits.length ? digits[k] : '';
      }
      _nodes[math.min(digits.length, 5)].requestFocus();
    } else {
      _ctrls[i].text = digits;
      if (digits.isNotEmpty && i < 5) _nodes[i + 1].requestFocus();
    }
    setState(() {
      _status = 'idle';
      _error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final boxes = Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 6; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _box(i, pal),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          const _LogoHeader(titleSize: 24),
          const SizedBox(height: 8), // collapsed CSS margins (8 + 16 → 16)
          Text(
            app.p('otpTitle'),
            textAlign: TextAlign.center,
            style: ts(context, 26, weight: w900, height: 1.25),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${app.p('otpSub')} '),
                TextSpan(
                  text: app.otpTarget,
                  style: ts(context, 14, weight: w700),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: ts(context, 14, color: pal.muted),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _anim,
            builder: (context, child) {
              final t = _anim.value;
              if (_status == 'wrong') {
                // otpShake keyframes: 0 -7 7 -5 5 0
                const pts = [0.0, -7.0, 7.0, -5.0, 5.0, 0.0];
                final seg = (t * 5).clamp(0.0, 4.999);
                final k = seg.floor();
                final dx =
                    pts[k] +
                    (pts[k + 1] - pts[k]) * Curves.ease.transform(seg - k);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              }
              if (_status == 'correct') {
                final s = t < .5
                    ? 1 + .12 * Curves.ease.transform(t / .5)
                    : 1.12 - .12 * Curves.ease.transform((t - .5) / .5);
                return Transform.scale(scale: s, child: child);
              }
              return child!;
            },
            child: boxes,
          ),
          if (_status == 'correct')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '✓ ${app.tr('رمز صحيح', 'کۆدی دروست', 'Correct code')}',
                style: ts(context, 14, weight: w900, color: Fixed.green),
              ),
            ),
          if (_status == 'wrong')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                app.tr('رمز خاطئ', 'کۆدی هەڵە', 'Wrong code'),
                style: ts(context, 13, weight: w700, color: Fixed.red),
              ),
            ),
          if (_error.isNotEmpty) _ErrorText(_error, top: 12),
          const SizedBox(height: 16),
          _seconds > 0
              ? Text(
                  '${app.p('resendIn')} 00:${_seconds.toString().padLeft(2, '0')}',
                  style: ts(context, 13, color: pal.muted),
                )
              : GestureDetector(
                  onTap: () async {
                    for (final c in _ctrls) {
                      c.clear();
                    }
                    setState(() {
                      _error = '';
                      _startTimer();
                    });
                    _nodes[0].requestFocus();
                    final err = await app.resendOtp();
                    if (err != null && mounted) setState(() => _error = err);
                  },
                  child: Text(
                    app.p('resend'),
                    style: ts(context, 13, weight: w900, color: pal.accent),
                  ),
                ),
          const SizedBox(height: 16),
          BlockButton(
            label: app.p('confirmBtn'),
            color: pal.accent,
            textColor: Colors.white,
            vPad: 16,
            onTap: _confirm,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => app.goAuth('login'),
            child: Text(
              app.p('backLogin'),
              style: ts(context, 13, weight: w700, color: pal.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(int i, Palette pal) {
    Color border = pal.cardBorder, fill = pal.inputBg, text = pal.ink;
    if (_status == 'wrong') {
      border = Fixed.red;
      fill = const Color(0xFFFFF0EF);
      text = Fixed.red;
    } else if (_status == 'correct') {
      border = Fixed.green;
      fill = const Color(0xFFEAF9EE);
      text = const Color(0xFF0E7A3E);
    }
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: border),
    );
    return SizedBox(
      width: 48,
      height: 56,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (e) {
          if (e is KeyDownEvent &&
              e.logicalKey == LogicalKeyboardKey.backspace &&
              _ctrls[i].text.isEmpty &&
              i > 0) {
            _nodes[i - 1].requestFocus();
          }
        },
        child: TextField(
          controller: _ctrls[i],
          focusNode: _nodes[i],
          onChanged: (v) => _onDigit(i, v),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          expands: true,
          maxLines: null,
          cursorColor: pal.accent,
          style: ts(context, 22, weight: w900, color: text, height: 1.2),
          decoration: InputDecoration(
            filled: true,
            fillColor: fill,
            contentPadding: EdgeInsets.zero,
            enabledBorder: outline,
            focusedBorder: outline,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Forgot password

class _Forgot extends StatefulWidget {
  const _Forgot();

  @override
  State<_Forgot> createState() => _ForgotState();
}

class _ForgotState extends State<_Forgot> {
  late final TextEditingController _phone;
  late final TextEditingController _email;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    _phone = TextEditingController(text: app.forgotPhone);
    _email = TextEditingController(text: app.forgotEmail);
  }

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final method = app.forgotMethod;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _LogoHeader(titleSize: 24),
          const SizedBox(height: 8), // collapsed CSS margins (8 + 16 → 16)
          Text(
            app.p('forgotTitle'),
            style: ts(context, 26, weight: w900, height: 1.25),
          ),
          const SizedBox(height: 4),
          Text(app.p('forgotSub'), style: ts(context, 14, color: pal.muted)),
          const SizedBox(height: 24),
          _Segmented(
            value: method,
            onChanged: (v) => setState(() => app.forgotMethod = v),
          ),
          const SizedBox(height: 12),
          FieldLabel(
            method == 'phone'
                ? app.tr('رقم الهاتف', 'ژمارەی تەلەفۆن', 'Phone Number')
                : app.tr('الإيميل', 'ئیمەیڵ', 'Email'),
          ),
          const SizedBox(height: 4),
          method == 'phone'
              ? _PhoneField(
                  controller: _phone,
                  onChanged: (v) => app.forgotPhone = v,
                )
              : _EmailField(
                  controller: _email,
                  onChanged: (v) => app.forgotEmail = v,
                ),
          if (_error.isNotEmpty) _ErrorText(_error, top: 12),
          const SizedBox(height: 16),
          BlockButton(
            label: method == 'phone'
                ? app.tr(
                    'إرسال رمز عبر SMS',
                    'ناردنی کۆد بە SMS',
                    'Send code via SMS',
                  )
                : app.tr(
                    'إرسال رمز عبر الإيميل',
                    'ناردنی کۆد بە ئیمەیڵ',
                    'Send code via Email',
                  ),
            color: pal.accent,
            textColor: Colors.white,
            vPad: 16,
            onTap: () {
              final v = method == 'phone'
                  ? _phone.text.trim()
                  : _email.text.trim();
              if (v.isEmpty) {
                setState(() => _error = app.p('fillAll'));
                return;
              }
              if (method != 'phone' && LabApi.enabled) {
                setState(() => _error = app.tr('استعادة كلمة المرور تتم برقم الهاتف المسجل', 'بە ژمارەی مۆبایل', 'Password reset works with the registered phone number'));
                return;
              }
              app.startForgot(v).then((err) {
                if (err != null && mounted) setState(() => _error = err);
              });
            },
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => app.goAuth('login'),
            child: Text(
              app.p('backLogin'),
              textAlign: TextAlign.center,
              style: ts(context, 13, weight: w700, color: pal.muted),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reset password

class _Reset extends StatefulWidget {
  const _Reset();

  @override
  State<_Reset> createState() => _ResetState();
}

class _ResetState extends State<_Reset> {
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pal.accent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'L',
                style: ts(context, 34, weight: w900, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            app.p('resetTitle'),
            style: ts(context, 26, weight: w900, height: 1.25),
          ),
          const SizedBox(height: 4),
          Text(app.p('resetSub'), style: ts(context, 14, color: pal.muted)),
          const SizedBox(height: 24),
          FieldLabel(app.p('newPass')),
          const SizedBox(height: 4),
          _PasswordField(controller: _new),
          const SizedBox(height: 12),
          FieldLabel(app.p('confirmPass')),
          const SizedBox(height: 4),
          _PasswordField(controller: _confirm),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ErrorText(_error),
          ],
          const SizedBox(height: 12),
          BlockButton(
            label: app.p('saveNewPass'),
            color: pal.accent,
            textColor: Colors.white,
            vPad: 16,
            onTap: () {
              if (_new.text.isEmpty || _confirm.text.isEmpty) {
                setState(() => _error = app.p('fillAll'));
                return;
              }
              if (_new.text != _confirm.text) {
                setState(() => _error = app.p('passMismatch'));
                return;
              }
              if (_new.text.length < 8) {
                setState(() => _error = app.tr('كلمة المرور 8 أحرف على الأقل', 'وشەی نهێنی لانیکەم ٨ پیت', 'Password must be at least 8 characters'));
                return;
              }
              app.confirmReset(_new.text).then((err) {
                if (!mounted) return;
                if (err != null) {
                  setState(() => _error = err);
                  return;
                }
                app.goAuth('login');
                app.setAuthBanner(app.p('changedToast'));
              });
            },
          ),
        ],
      ),
    );
  }
}
