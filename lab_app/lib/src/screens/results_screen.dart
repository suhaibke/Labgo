import 'package:flutter/material.dart';

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
          SearchBarBox(
            hint: app.w('searchPatientTest'),
            onChanged: app.setResultsSearch,
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
          const SizedBox(height: 12),
          for (final r in app.receivedFiltered) ...[
            Tap(
              onTap: () {
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

class _ResultRow extends StatelessWidget {
  final Patient patient;
  const _ResultRow({required this.patient});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    Widget action({
      required String icon,
      required String label,
      required VoidCallback onTap,
      Gradient? gradient,
      Color? color,
    }) => Tap(
      onTap: onTap,
      scale: .95,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: gradient,
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LIcon(icon, size: 16, color: Colors.white),
            const SizedBox(height: 2),
            Text(
              label,
              style: ts(
                context,
                10,
                weight: w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );

    return CardBox(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Tap(
              onTap: () => app.openPatient(patient),
              child: Row(
                children: [
                  InitialsAvatar(initials(patient.name)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts(context, 15, weight: w700),
                        ),
                        Text(
                          patient.tests.join(', '),
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
                      Text(
                        patient.time,
                        style: ts(context, 12, color: pal.muted),
                      ),
                      StatusPill(patient.status),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          action(
            icon: 'Send',
            label: app.tr('إرسال', 'ناردن', 'Send'),
            gradient: Fixed.sendGradient,
            onTap: () => app.openSendSheet(patient),
          ),
          const SizedBox(width: 8),
          action(
            icon: 'Printer',
            label: app.tr('طباعة النتائج', 'چاپی ئەنجام', 'Print Results'),
            color: pal.accent,
            onTap: () => app.openPrint(patient, patient.results),
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
    final rows = resultRows(p);

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
                ? 'ID LG-$idTail • ${p.time} • 27 Sep • ${p.permanent}'
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
                  _ResultEntry(key: ValueKey(r.test), row: r),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 4),
                Tap(
                  onTap: app.saveResults,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      app.w('saveResults'),
                      style: ts(context, 16, weight: w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Tap(
                  onTap: () => app.openPrint(p, app.draft),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: pal.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const LIcon('Printer', size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          app.tr(
                            'طباعة النتائج',
                            'چاپکردنی ئەنجامەکان',
                            'Print Results',
                          ),
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
  const _ResultEntry({super.key, required this.row});

  @override
  State<_ResultEntry> createState() => _ResultEntryState();
}

class _ResultEntryState extends State<_ResultEntry> {
  late final TextEditingController _c = TextEditingController(
    text: context.app.draft[widget.row.test] ?? '',
  );

  @override
  void dispose() {
    _c.dispose();
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
