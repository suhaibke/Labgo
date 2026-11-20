import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../results_logic.dart';
import '../theme.dart';
import '../ui.dart';

/// "Results & printing" list.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final list = app.resultsList;
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
          Text(app.w('results'), style: ts(context, 28, weight: w700)),
          Text(
            '${app.w('resultsSub')} • ${app.labDisplayName} • ${app.doctorName}',
            style: ts(context, 13, color: pal.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: _ResultsSearch()),
              const SizedBox(width: 8),
              // Date filter: a small icon; tinted while a date is chosen.
              Tap(
                onTap: app.toggleResultsDate,
                child: Container(
                  width: 45,
                  height: 45,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: app.resultsDateKey != 'all' ? pal.accent : pal.searchBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: LIcon('Calendar', size: 18, color: app.resultsDateKey != 'all' ? Colors.white : pal.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final f in const ['All', 'Ready', 'Pending']) ...[
                if (f != 'All') const SizedBox(width: 8),
                FilterChipPill(
                  label: f == 'All'
                      ? app.w('all')
                      : f == 'Ready'
                      ? app.w('ready')
                      : app.w('pending'),
                  selected: app.resultsFilter == f,
                  scale: 1,
                  onTap: () => app.setResultsFilter(f),
                ),
              ],
            ],
          ),
          if (app.resultsDateOpen) ...[
            const SizedBox(height: 8),
            const _DateFilter(),
          ],
          const SizedBox(height: 12),
          for (final r in app.receivedFiltered) ...[
            Tap(
              onTap: () {
                if (LabApi.enabled) {
                  app.openIncoming(r);
                  return;
                }
                final match = app.patients.where(
                  (m) => m.name.toLowerCase() == r.patient.toLowerCase(),
                );
                if (match.isNotEmpty) {
                  app.openPatient(match.first);
                } else {
                  app.toast(
                    '${app.d('receivedSample')}: ${r.patient} • ${r.test}',
                  );
                }
              },
              child: CardBox(
                child: Row(
                  children: [
                    InitialsAvatar(initials(r.patient)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.patient,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ts(context, 15, weight: w700),
                          ),
                          Text(
                            '${r.test} • ${r.lab}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ts(context, 12, color: pal.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(r.code, style: ts(context, 12, color: pal.muted)),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: pal.chipBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: pal.line),
                          ),
                          child: Text(
                            app.d('receivedSample'),
                            style: ts(
                              context,
                              11,
                              weight: w700,
                              color: pal.muted2,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final p in list) ...[
            _ResultRow(patient: p),
            const SizedBox(height: 12),
          ],
          if (list.isEmpty && app.receivedFiltered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                app.w('searchPatientTest'),
                textAlign: TextAlign.center,
                style: ts(context, 13, color: pal.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Date filter chips: all, today, yesterday, last 7 days, this month, a chosen day.
class _DateFilter extends StatelessWidget {
  const _DateFilter();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final key = app.resultsDateKey;
    final d = app.resultsDay;
    final chips = [
      ('all', app.tr('كل التواريخ', 'هەموو بەروارەکان', 'All dates')),
      ('today', app.tr('اليوم', 'ئەمڕۆ', 'Today')),
      ('yesterday', app.tr('أمس', 'دوێنێ', 'Yesterday')),
      ('week', app.tr('آخر 7 أيام', '7 ڕۆژی ڕابردوو', 'Last 7 days')),
      ('month', app.tr('هذا الشهر', 'ئەم مانگە', 'This month')),
    ];
    Future<void> pickDay() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: d ?? now,
        firstDate: DateTime(now.year - 5),
        lastDate: now,
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: pal.accent)),
          child: child!,
        ),
      );
      if (picked != null) app.setResultsDate('day', day: picked);
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in chips) ...[
            FilterChipPill(label: c.$2, selected: key == c.$1, scale: .9, onTap: () => app.setResultsDate(c.$1)),
            const SizedBox(width: 6),
          ],
          FilterChipPill(
            label: key == 'day' && d != null ? '${d.day}/${d.month}/${d.year}' : app.tr('تاريخ محدد', 'بەرواری دیاریکراو', 'Pick a date'),
            icon: 'Calendar',
            selected: key == 'day',
            scale: .9,
            onTap: pickDay,
          ),
        ],
      ),
    );
  }
}

/// Search box that keeps showing the active search when the screen is rebuilt.
class _ResultsSearch extends StatefulWidget {
  const _ResultsSearch();

  @override
  State<_ResultsSearch> createState() => _ResultsSearchState();
}

class _ResultsSearchState extends State<_ResultsSearch> {
  late final _c = TextEditingController(text: context.app.resultsSearch);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return SearchBarBox(
      controller: _c,
      hint: app.tr('ابحث بالاسم أو كود العينة أو الهاتف…', 'بە ناو، کۆدی نموونە یان مۆبایل بگەڕێ…', 'Search name, sample code or phone…'),
      onChanged: app.setResultsSearch,
    );
  }
}

class _ResultRow extends StatelessWidget {
  final Patient patient;
  const _ResultRow({required this.patient});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    // Compact round action (icon only) so the name gets the row's width.
    Widget action({
      required String icon,
      required VoidCallback onTap,
      Gradient? gradient,
      Color? color,
      Color iconColor = Colors.white,
      Border? border,
    }) => Tap(
      onTap: onTap,
      scale: .9,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: gradient, color: color, shape: BoxShape.circle, border: border),
        child: LIcon(icon, size: 16, color: iconColor),
      ),
    );

    final code = patient.shortCode;
    final pid = patient.permanent;
    return CardBox(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Tap(
              onTap: () => app.openPatient(patient),
              child: Row(
                children: [
                  InitialsAvatar(initials(patient.name)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                patient.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ts(context, 15, weight: w700),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // sample / receipt code, searchable
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: pal.line)),
                              child: Text(code, textDirection: TextDirection.ltr, style: ts(context, 10.5, weight: w700, color: pal.muted2, height: 1.4)),
                            ),
                          ],
                        ),
                        if (app.sentFor(patient.id) case final sent?)
                          Text(
                            '${app.tr('مرسل إلى', 'نێردرا بۆ', 'Sent to')} ${sent.lab} • ${sent.tracking}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ts(context, 11.5, weight: w700, color: pal.accent),
                          ),
                        Text(
                          [if (pid.isNotEmpty && pid != code) pid, patient.tests.join(', ')].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts(context, 12, color: pal.muted),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            StatusPill(patient.status),
                            const SizedBox(width: 6),
                            Text(patient.time, style: ts(context, 11, color: pal.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          action(
            icon: 'Send',
            gradient: context.pal.accentGradient,
            onTap: () => app.openSendSheet(patient),
          ),
          const SizedBox(width: 6),
          action(
            icon: 'Printer',
            color: pal.accent,
            onTap: () => app.openPrint(patient, patient.results),
          ),
          const SizedBox(width: 2),
          Tap(
            onTap: () => app.openRowMenu(patient),
            scale: .9,
            child: SizedBox(
              width: 30,
              height: 36,
              child: Center(child: LIcon('EllipsisVertical', size: 20, color: pal.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Result entry for one patient (design: results + Xn).
class ResultDetailScreen extends StatelessWidget {
  const ResultDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final p = app.selectedPatient!;
    final idTail = p.id.length > 4 ? p.id.substring(p.id.length - 4) : p.id;
    // Unit / range typed for sent tests count before they are saved.
    final rows = resultRows(p.copyWith(resultMeta: {...p.resultMeta, ...app.draftMeta}));

    Widget infoCell(
      String label,
      String value,
      double size, {
      bool ltr = false,
    }) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: pal.chipBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: ts(context, 11, color: pal.muted),
            ),
            Text(
              value,
              textAlign: TextAlign.center,
              textDirection: ltr ? TextDirection.ltr : null,
              style: ts(context, size, weight: w700),
            ),
          ],
        ),
      ),
    );

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
            child: BackLink(label: app.w('back'), onTap: app.closePatient),
          ),
          Text(p.name, style: ts(context, 26, weight: w700, height: 1.25)),
          Text(
            p.createdAt == null
                ? 'ID LG-$idTail • ${p.time} • ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} • ${p.permanent}'
                // Server data: patient ID, time and the order's real date.
                : 'ID ${p.permanent} • ${p.time} • ${p.createdAt!.day}/${p.createdAt!.month}/${p.createdAt!.year}',
            style: ts(context, 13, color: pal.muted),
          ),
          const SizedBox(height: 12),
          CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  app.w('patientInfo'),
                  style: ts(context, 12, weight: w700, color: pal.muted),
                ),
                const SizedBox(height: 8),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      infoCell(app.w('age'), p.age, 14),
                      const SizedBox(width: 8),
                      infoCell(
                        app.w('doctorLabel'),
                        p.doctor.isEmpty ? '—' : p.doctor,
                        12,
                      ),
                      const SizedBox(width: 8),
                      infoCell(app.w('phone'), p.phone, 11, ltr: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  app.w('resultDetail'),
                  style: ts(context, 14, weight: w700),
                ),
                const SizedBox(height: 8),
                for (final r in rows) ...[
                  _ResultEntry(key: ValueKey(r.test), row: r, sent: app.sentTest(p, r.test)),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 4),
                // Upload the result as a photo or PDF (instead of / with typed values).
                Tap(
                  onTap: app.resultFiles.containsKey(p.id) ? () => app.openResultFile(p.id) : app.uploadResultFile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: pal.chipBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: pal.line),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LIcon(app.resultFiles.containsKey(p.id) ? 'FileText' : 'ImagePlus', size: 16, color: pal.accent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            app.resultFiles.containsKey(p.id)
                                ? '${app.tr('ملف النتيجة', 'فایلی ئەنجام', 'Result file')}: ${app.resultFiles[p.id]!.$1}'
                                : app.tr('رفع النتيجة كصورة أو PDF', 'بارکردنی ئەنجام وەک وێنە یان PDF', 'Upload result as photo or PDF'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ts(context, 13, weight: w700),
                          ),
                        ),
                        if (app.resultFiles.containsKey(p.id)) ...[
                          const SizedBox(width: 8),
                          Tap(
                            onTap: app.uploadResultFile,
                            child: Text(app.tr('تغيير', 'گۆڕین', 'Change'), style: ts(context, 12, weight: w700, color: pal.accent)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Parts cut from the uploaded file; printed in the report.
                if (app.resultFiles.containsKey(p.id)) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 64,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final (i, img) in (app.resultCrops[p.id] ?? const []).indexed)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: Stack(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(color: Colors.white, child: Image.memory(img, width: 86, height: 64, fit: BoxFit.contain)),
                              ),
                              PositionedDirectional(
                                top: 2,
                                end: 2,
                                child: Tap(
                                  onTap: () => app.removeCrop(p.id, i),
                                  child: Container(width: 20, height: 20, alignment: Alignment.center,
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const LIcon('X', size: 11, color: Colors.white)),
                                ),
                              ),
                            ]),
                          ),
                        if ((app.resultCrops[p.id]?.length ?? 0) < 4)
                          Tap(
                            onTap: () => app.openCropper(p.id),
                            child: Container(
                              width: 86,
                              height: 64,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: pal.line)),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                LIcon('Crop', size: 18, color: pal.accent),
                                const SizedBox(height: 2),
                                Text(app.tr('قص جزء', 'بڕین', 'Crop part'), style: ts(context, 11, weight: w700)),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (app.resultCrops[p.id]?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(app.tr('الأجزاء المقصوصة تُطبع ضمن تقرير النتيجة', 'بەشە بڕاوەکان لە ڕاپۆرتدا چاپ دەکرێن', 'Cropped parts are printed in the result report'),
                          style: ts(context, 11, color: pal.muted)),
                    ),
                ],
                const SizedBox(height: 8),
                Tap(
                  onTap: app.resultsLocked ? app.unlockResults : app.saveResults,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: app.resultsLocked ? pal.ink : pal.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LIcon(app.resultsLocked ? 'Pencil' : 'Check', size: 16, color: app.resultsLocked ? pal.appBg : Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          app.resultsLocked ? app.tr('تعديل النتائج', 'دەستکاریکردنی ئەنجام', 'Edit results') : app.w('saveResults'),
                          style: ts(context, 16, weight: w700, color: app.resultsLocked ? pal.appBg : Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // What the patient still owes (pay later / partial), with "Pay off".
          if (p.due > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD97706).withValues(alpha: .35)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.tr('على المريض دين', 'نەخۆش قەرزارە', 'The patient owes'), style: ts(context, 12, color: pal.muted)),
                        Text('${_mny(p.due)} IQD', textDirection: TextDirection.ltr,
                            style: ts(context, 17, weight: w900, color: const Color(0xFFD97706))),
                        if (p.isPartlyPaid)
                          Text(app.tr('مدفوع ${_mny(p.collected)} من ${_mny(p.price)}', 'دراو ${_mny(p.collected)} لە ${_mny(p.price)}',
                              'Paid ${_mny(p.collected)} of ${_mny(p.price)}'), style: ts(context, 11, color: pal.muted)),
                      ],
                    ),
                  ),
                  Tap(
                    onTap: () => app.openSettle(p.id, p.name, p.due),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(999)),
                      child: Text(app.tr('تسديد', 'دانەوە', 'Pay off'), style: ts(context, 13, weight: w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Tap(
                  onTap: app.approveResultsFromDetail,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: pal.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const LIcon('BadgeCheck', size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          app.approving
                              ? '…'
                              : p.status == 'Completed'
                              ? app.tr('معتمدة ✓', 'پەسەندکراوە ✓', 'Approved ✓')
                              : app.tr('اعتماد', 'پەسەندکردن', 'Approve'),
                          style: ts(
                            context,
                            13,
                            weight: w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tap(
                  onTap: () => app.openSendSheet(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: pal.chipBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: pal.line),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LIcon('Send', size: 16, color: pal.ink),
                        const SizedBox(width: 6),
                        Text(
                          app.w('sendResult'),
                          style: ts(context, 13, weight: w700),
                        ),
                      ],
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

/// One result input with the coloured low/normal/high indicator.
class _ResultEntry extends StatefulWidget {
  final ResultRow row;
  /// Set when this test was sent to another lab: its unit / range can be typed.
  final Referral? sent;
  const _ResultEntry({super.key, required this.row, this.sent});

  @override
  State<_ResultEntry> createState() => _ResultEntryState();
}

class _ResultEntryState extends State<_ResultEntry> {
  late final TextEditingController _c = TextEditingController(
    text: context.app.draft[widget.row.test] ?? '',
  );
  late final (String, String) _meta = context.app.sentMeta(widget.row.test);
  late final TextEditingController _unit = TextEditingController(text: _meta.$1);
  late final TextEditingController _range = TextEditingController(text: _meta.$2);

  @override
  void dispose() {
    _c.dispose();
    _unit.dispose();
    _range.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final r = widget.row;
    final value = app.draft[r.test] ?? '';
    final m = classify(value, r.normalRow);
    final color = m == 'low'
        ? Fixed.blue
        : m == 'high'
        ? Fixed.red
        : m == 'normal'
        ? Fixed.green
        : null;
    final label = m == 'low'
        ? app.d('lowLabel')
        : m == 'high'
        ? app.d('highLabel')
        : m == 'normal'
        ? app.d('normalLabel')
        : '';
    final symbol = m == 'low'
        ? '↓'
        : m == 'high'
        ? '↑'
        : m == 'normal'
        ? '✓'
        : '•';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.chipBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.sent case final sent?)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: pal.softAccent, borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    LIcon('Send', size: 11, color: pal.accent),
                    const SizedBox(width: 4),
                    Text(app.tr('مرسل', 'نێردراو', 'Sent'), style: ts(context, 11, weight: w700, color: pal.accent, height: 1.45)),
                  ]),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('${sent.lab} • ${sent.tracking}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(context, 11.5, color: pal.muted)),
                ),
              ]),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.label, style: ts(context, 14, weight: w700)),
              const SizedBox(width: 8),
              const Spacer(),
              Flexible(
                flex: 4,
                child: Text(
                  '${app.w('normalRange')}: ${r.range} ${r.units}',
                  textAlign: TextAlign.end,
                  style: ts(context, 12, color: pal.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: BoxField(
                  controller: _c,
                  readOnly: app.resultsLocked,
                  onTap: app.resultsLocked ? () => app.toast(app.tr('اضغط «تعديل النتائج» للتعديل', 'بۆ دەستکاری «دەستکاریکردنی ئەنجام» دابگرە', 'Tap "Edit results" to change them')) : null,
                  onChanged: (v) => app.setDraft(r.test, v),
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  hint: app.w('enterResult'),
                  fontSize: 14,
                  vPad: 10,
                  radius: 12,
                ),
              ),
              const SizedBox(width: 8),
              Text(r.units, style: ts(context, 12, color: pal.muted)),
              const SizedBox(width: 8),
              _ResultDot(
                key: ValueKey(m ?? 'empty'),
                color: color,
                symbol: symbol,
                live: m != null,
              ),
            ],
          ),
          // A sent test: its unit and normal range as the other lab reported them (this order only).
          if (widget.sent != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                flex: 2,
                child: BoxField(
                  controller: _unit,
                  readOnly: app.resultsLocked,
                  hint: app.tr('الوحدة', 'یەکە', 'Unit'),
                  ltr: true,
                  fontSize: 13,
                  vPad: 8,
                  radius: 12,
                  onChanged: (v) => app.setDraftMeta(r.test, unit: v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: BoxField(
                  controller: _range,
                  readOnly: app.resultsLocked,
                  hint: app.tr('المعدل الطبيعي (30 - 100)', 'ئاستی ئاسایی', 'Normal range (30 - 100)'),
                  ltr: true,
                  fontSize: 13,
                  vPad: 8,
                  radius: 12,
                  onChanged: (v) => app.setDraftMeta(r.test, range: v),
                ),
              ),
            ]),
          ],
          if (m != null) ...[
            const SizedBox(height: 6),
            Text(
              '$label • ${r.range} ${r.units} • ${r.category}',
              style: ts(context, 12, weight: w700, color: color),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${app.d('categoryLabel')}: ${r.category}',
            style: ts(context, 11, color: pal.muted),
          ),
        ],
      ),
    );
  }
}

/// 40px status dot: `resultSettle` on change and the green `resultPulse` ring.
class _ResultDot extends StatefulWidget {
  final Color? color;
  final String symbol;
  final bool live;
  const _ResultDot({
    super.key,
    required this.color,
    required this.symbol,
    required this.live,
  });

  @override
  State<_ResultDot> createState() => _ResultDotState();
}

class _ResultDotState extends State<_ResultDot> with TickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..forward();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void initState() {
    super.initState();
    if (widget.live) _pulse.repeat();
  }

  @override
  void dispose() {
    _settle.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const curve = Cubic(.2, .8, .2, 1);
    return AnimatedBuilder(
      animation: Listenable.merge([_settle, _pulse]),
      builder: (context, _) {
        // resultSettle: scale 1.45 rot -10° → .92 rot 4° (60%) → 1 rot 0
        final t = _settle.value;
        double scale, rot;
        if (t < .6) {
          final u = curve.transform(t / .6);
          scale = 1.45 + (.92 - 1.45) * u;
          rot = -10 + 14 * u;
        } else {
          final u = curve.transform((t - .6) / .4);
          scale = .92 + .08 * u;
          rot = 4 - 4 * u;
        }
        // resultPulse: 0 0 0 0 → 0 0 0 6px (alpha .35 → 0) → back, ease-in-out
        final pt = _pulse.value;
        final half = pt < .5
            ? Curves.easeInOut.transform(pt / .5)
            : 1 - Curves.easeInOut.transform((pt - .5) / .5);
        return Transform.rotate(
          angle: rot * 3.1415926535 / 180,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.color ?? pal.track,
                shape: BoxShape.circle,
                boxShadow: widget.live
                    ? [
                        BoxShadow(
                          color: Color.fromRGBO(52, 199, 89, .35 * (1 - half)),
                          spreadRadius: 6 * half,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                widget.symbol,
                style: ts(
                  context,
                  16,
                  weight: w900,
                  color: widget.color != null ? Colors.white : pal.muted,
                  height: 1,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 25000 -> "25,000".
String _mny(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
