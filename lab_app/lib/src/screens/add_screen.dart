import 'package:flutter/material.dart';

import '../catalog_data.dart';
import '../ui.dart';
import 'auth_screens.dart' show AuthInput, FieldLabel;

/// "Add Patient": patient info, tests / packages, sample, urgency, total.
class AddScreen extends StatelessWidget {
  const AddScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final w = app.w, d = app.d;
    final b2b = app.addMode == 'B2B';
    final lang = app.lang;
    String l3(String en, String ar, String ku) => lang == 'en'
        ? en
        : lang == 'ar'
        ? ar
        : ku;

    Widget section(List<Widget> children, {double gap = 12}) => CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0 && gap > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      ),
    );

    final ageLetter = app.addAgeUnit == 'Y'
        ? d('yLetter')
        : app.addAgeUnit == 'M'
        ? d('mLetter')
        : d('dLetter');
    final ageWord = app.addAgeUnit == 'Y'
        ? d('years')
        : app.addAgeUnit == 'M'
        ? d('months')
        : d('days');

    Widget genderBtn(String g, String symbol, Color idle) {
      final on = app.addGender == g;
      return GestureDetector(
        onTap: () => app.updateAdd(() => app.addGender = g),
        child: Container(
          width: 38,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? pal.accent : pal.chipBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: pal.cardBorder),
          ),
          // drawn as a vector so it never falls back to a colour emoji
          child: LIcon(
            symbol,
            size: 15,
            strokeWidth: 2.2,
            color: on ? Colors.white : idle,
          ),
        ),
      );
    }

    final looseTests = app.addLooseTests;
    final packages = app.addSelectedPackages;
    final pkgMatches = app.addPackageMatches;
    final testMatches = app.addTestMatches;

    return Padding(
      key: ValueKey('add-${app.addFormVersion}'),
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        112 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(w('addPatient'), style: ts(context, 28, weight: w700)),
                    const SizedBox(height: 2),
                    Text(w('addSub'), style: ts(context, 13, color: pal.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tap(
                scale: .95,
                onTap: () =>
                    app.updateAdd(() => app.addMode = b2b ? 'B2C' : 'B2B'),
                child: Container(
                  width: 68,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: b2b ? pal.accent : pal.chipBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: pal.cardBorder),
                  ),
                  child: Text(
                    'B2B',
                    style: ts(
                      context,
                      12,
                      weight: w900,
                      color: b2b ? Colors.white : pal.muted2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (b2b) ...[
            const SizedBox(height: 8),
            Text(
              d('b2bDiscountLabel'),
              style: ts(context, 11, weight: w700, color: pal.accent),
            ),
            const SizedBox(height: 4),
            _SuggestField(
              key: ValueKey('co-${app.addFormVersion}'),
              initial: app.addCompany,
              hint: w('companyPh'),
              vPad: 10,
              fontSize: 14,
              matches: () => app.addCompanyMatches,
              onChanged: (v) => app.updateAdd(() => app.addCompany = v),
            ),
          ],
          const SizedBox(height: 12),
          section([
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FieldLabel(w('fullName')),
                const SizedBox(height: 4),
                _KeepInput(
                  initial: app.addName,
                  hint: app.tr('اسم المريض', 'ناوی نەخۆش', 'Patient name'),
                  onChanged: (v) => app.addName = v,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FieldLabel(w('age')),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: _KeepInput(
                          initial: app.addAge,
                          hint: app.tr('العمر', 'تەمەن', 'Age'),
                          keyboard: TextInputType.number,
                          vPad: 10,
                          onChanged: (v) => app.updateAdd(() => app.addAge = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: pal.segmented,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          for (final u in [
                            ('Y', d('yLetter')),
                            ('M', d('mLetter')),
                            ('D', d('dLetter')),
                          ])
                            GestureDetector(
                              onTap: () =>
                                  app.updateAdd(() => app.addAgeUnit = u.$1),
                              child: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: app.addAgeUnit == u.$1
                                      ? pal.accent
                                      : null,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  u.$2,
                                  style: ts(
                                    context,
                                    13,
                                    weight: w900,
                                    color: app.addAgeUnit == u.$1
                                        ? Colors.white
                                        : pal.muted2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    genderBtn('Male', 'Mars', const Color(0xFF5B7A99)),
                    const SizedBox(width: 6),
                    genderBtn('Female', 'Venus', const Color(0xFFB0708A)),
                  ],
                ),
                if (app.addAge.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${app.addAge}$ageLetter • ${app.addAge} $ageWord',
                    style: ts(context, 11, color: pal.muted),
                  ),
                ],
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FieldLabel(w('phone')),
                const SizedBox(height: 4),
                _KeepInput(
                  initial: app.addPhone,
                  hint: app.tr('رقم الهاتف', 'ژمارەی تەلەفۆن', 'Phone number'),
                  forceLtr: true,
                  keyboard: TextInputType.phone,
                  onChanged: (v) => app.addPhone = v,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FieldLabel(w('doctor')),
                const SizedBox(height: 4),
                _SuggestField(
                  key: ValueKey('doc-${app.addFormVersion}'),
                  initial: app.addDoctor,
                  hint: app.w('doctorPh'),
                  matches: () => app.addDoctorMatches,
                  onChanged: (v) => app.updateAdd(() => app.addDoctor = v),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          section(gap: 0, [
            const SizedBox(height: 16),
            FieldLabel(
              l3(
                'Search test or package',
                'ابحث عن فحص أو باقة',
                'بەدوای پشکنین یان پاکێجدا بگەڕێ',
              ),
            ),
            const SizedBox(height: 8),
            SearchBarBox(
              key: ValueKey(
                'search-${app.addFormVersion}-${app.addTests.length}-${app.addPackages.length}',
              ),
              hint: l3(
                'Search by name or package code...',
                'ابحث بالاسم أو رمز الباقة...',
                'بەدوای ناو یان کۆدی پاکێجدا بگەڕێ...',
              ),
              onChanged: (v) => app.updateAdd(() => app.addSearch = v),
            ),
            if (app.addSearch.trim().isNotEmpty &&
                (pkgMatches.isNotEmpty || testMatches.isNotEmpty))
              Container(
                margin: const EdgeInsets.only(top: 8),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: pal.chipBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pal.line),
                ),
                child: Column(
                  children: [
                    for (final t in testMatches)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => app.updateAdd(() {
                          app.addTests = [...app.addTests, t.name];
                          app.addSearch = '';
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.name,
                                  style: ts(context, 14, weight: w600),
                                ),
                              ),
                              Text(
                                formatNumber(testPrice(t.name, app.addMode)),
                                style: ts(
                                  context,
                                  14,
                                  weight: w600,
                                  color: pal.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final p in pkgMatches)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          app.addSearch = '';
                          app.togglePackage(p);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: ts(context, 14, weight: w600),
                                    ),
                                    Text(
                                      '${p.code.isNotEmpty ? '${p.code} • ' : ''}${p.tests.length} ${l3('tests', 'فحص', 'پشکنین')}',
                                      style: ts(context, 11, color: pal.muted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: pal.accent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  p.isOffer
                                      ? l3('Offer', 'عرض', 'ئۆفەر')
                                      : l3('Package', 'باقة', 'پاکێج'),
                                  style: ts(
                                    context,
                                    10,
                                    weight: w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatNumber(
                                  b2b ? packagePrice(p, 'B2B') : p.price,
                                ),
                                style: ts(
                                  context,
                                  14,
                                  weight: w600,
                                  color: pal.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (packages.isNotEmpty || looseTests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in packages)
                      _Tag(
                        label: p.name,
                        filled: true,
                        onRemove: () => app.togglePackage(p),
                      ),
                    for (final t in looseTests)
                      _Tag(
                        label: t,
                        filled: false,
                        onRemove: () => app.updateAdd(
                          () => app.addTests = app.addTests
                              .where((x) => x != t)
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FieldLabel(w('sample')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in [
                  (w('blood'), 'Blood'),
                  (w('urine'), 'Urine'),
                  (w('swab'), 'Swab'),
                  (d('stool'), 'Stool'),
                  (d('csf'), 'CSF'),
                ])
                  GestureDetector(
                    onTap: () => app.updateAdd(() => app.addSample = s.$2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: app.addSample == s.$2 ? pal.accent : pal.chipBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        s.$1,
                        style: ts(
                          context,
                          12,
                          weight: w700,
                          color: app.addSample == s.$2
                              ? Colors.white
                              : pal.muted2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (app.addSample == 'CSF') ...[
              const SizedBox(height: 4),
              Text(d('csfFull'), style: ts(context, 11, color: pal.muted)),
            ],
            const SizedBox(height: 16),
            FieldLabel(w('urgency')),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: pal.segmented,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  for (final u in [
                    (w('normal'), 'Normal'),
                    (w('urgent'), 'Urgent'),
                  ])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => app.updateAdd(() => app.addUrgency = u.$2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: app.addUrgency == u.$2 ? pal.accent : null,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            u.$1,
                            style: ts(
                              context,
                              13,
                              weight: w700,
                              color: app.addUrgency == u.$2
                                  ? Colors.white
                                  : pal.muted2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(w('notes')),
            const SizedBox(height: 4),
            _KeepInput(
              initial: app.addNotes,
              hint: w('notesPh'),
              fontSize: 14,
              lines: 2,
              onChanged: (v) => app.addNotes = v,
            ),
          ]),
          const SizedBox(height: 12),
          CardBox(
            child: Row(
              children: [
                Text(w('total'), style: ts(context, 16, weight: w700)),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${formatNumber(app.addTotal)} IQD',
                      style: ts(context, 20, weight: w700),
                    ),
                    if (b2b)
                      Text(
                        d('b2bDiscountLabel'),
                        style: ts(context, 11, weight: w700, color: pal.accent),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Tap(
                  onTap: () => app.submitPatient(payLater: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      w('addBtn'),
                      textAlign: TextAlign.center,
                      style: ts(context, 14, weight: w700, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tap(
                  onTap: () => app.submitPatient(payLater: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal.chipBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: pal.cardBorder),
                    ),
                    child: Text(
                      w('payLater'),
                      textAlign: TextAlign.center,
                      style: ts(context, 14, weight: w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 25000 -> "25,000" (toLocaleString in en).
String formatNumber(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$b';
}

/// Text input that keeps its own controller (value lives in app state).
class _KeepInput extends StatefulWidget {
  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool forceLtr;
  final TextInputType? keyboard;
  final double vPad;
  final double fontSize;
  final int lines;

  const _KeepInput({
    required this.initial,
    required this.hint,
    required this.onChanged,
    this.forceLtr = false,
    this.keyboard,
    this.vPad = 12,
    this.fontSize = 15,
    this.lines = 1,
  });

  @override
  State<_KeepInput> createState() => _KeepInputState();
}

class _KeepInputState extends State<_KeepInput> {
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
    if (widget.lines > 1) {
      return BoxField(
        controller: _c,
        hint: widget.hint,
        onChanged: widget.onChanged,
        fontSize: widget.fontSize,
        vPad: widget.vPad,
        lines: widget.lines,
      );
    }
    return AuthInput(
      controller: _c,
      hint: widget.hint,
      onChanged: widget.onChanged,
      forceLtr: widget.forceLtr,
      keyboard: widget.keyboard,
      vPad: widget.vPad,
      fontSize: widget.fontSize,
    );
  }
}

/// A text field that suggests names typed before (doctor, company / clinic / lab).
class _SuggestField extends StatefulWidget {
  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;
  final List<String> Function() matches;
  final double fontSize;
  final double vPad;
  const _SuggestField({
    super.key,
    required this.initial,
    required this.hint,
    required this.onChanged,
    required this.matches,
    this.fontSize = 15,
    this.vPad = 12,
  });

  @override
  State<_SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<_SuggestField> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  final _focus = FocusNode();
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _open = _focus.hasFocus));
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final matches = _open ? widget.matches() : const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BoxField(
          controller: _c,
          focusNode: _focus,
          hint: widget.hint,
          fontSize: widget.fontSize,
          vPad: widget.vPad,
          onChanged: (v) {
            widget.onChanged(v);
            setState(() => _open = true);
          },
        ),
        if (matches.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pal.cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(0, 20),
                  blurRadius: 25,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Column(
              children: [
                for (final v in matches)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _c.text = v;
                      widget.onChanged(v);
                      _focus.unfocus();
                      setState(() => _open = false);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Text(v, style: ts(context, 14, weight: w600)),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onRemove;
  const _Tag({
    required this.label,
    required this.filled,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fg = filled ? Colors.white : pal.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? pal.accent : pal.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: filled ? null : Border.all(color: pal.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: ts(context, 12, weight: w700, color: fg),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: LIcon('X', size: 13, color: fg),
          ),
        ],
      ),
    );
  }
}
