import 'package:flutter/material.dart';

import '../models.dart';
import '../results_logic.dart';
import '../theme.dart';
import '../ui.dart';

/// "Print Results": receipt-printer animation that feeds the lab report.
class PrintScreen extends StatelessWidget {
  const PrintScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final patient = app.printPatient;
    if (patient == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _PillButton(
          label: app.tr(
            'العودة للنتائج',
            'گەڕانەوە بۆ ئەنجامەکان',
            'Back to Results',
          ),
          color: pal.accent,
          textColor: Colors.white,
          onTap: app.closePrint,
        ),
      );
    }
    final merged = patient.copyWith(
      results: {...patient.results, ...app.printDraft},
    );
    final rows = resultRows(merged);
    final lang = app.lang;
    String t3(String ar, String ku, String en) => lang == 'ar'
        ? ar
        : lang == 'ku'
        ? ku
        : en;
    final backLabel = t3(
      'العودة للنتائج',
      'گەڕانەوە بۆ ئەنجامەکان',
      'Back to Results',
    );
    final stage = app.printStage;
    final status = stage == 'complete'
        ? t3(
            'اكتملت طباعة النتائج',
            'چاپی ئەنجامەکان تەواوبوو',
            'Results printed',
          )
        : stage == 'printing'
        ? t3(
            'جارٍ طباعة النتائج',
            'ئەنجامەکان چاپ دەکرێن',
            'Printing your results',
          )
        : 'Processing your order';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Tap(
                onTap: app.closePrint,
                scale: .95,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LIcon(
                        'ArrowLeft',
                        size: 15,
                        color: pal.muted,
                        flipX: app.rtl,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        backLabel,
                        style: ts(context, 13, weight: w700, color: pal.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 384),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  decoration: BoxDecoration(
                    color: pal.card,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: Shadows.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, c) {
                          final rootW = c.maxWidth;
                          final outW = (rootW * .8 + 48).clamp(0.0, rootW);
                          return Column(
                            children: [
                              _Machine(
                                stage: stage,
                                status: status,
                                title: patient.name,
                                trailing:
                                    '${rows.length} ${t3('نتيجة', 'ئەنجام', 'results')}',
                                sub:
                                    '${patient.permanent} • ${t3('تقرير النتائج', 'ڕاپۆرتی ئەنجامەکان', 'Lab Results Report')}',
                              ),
                              NegativeTopMargin(
                                amount: 16,
                                child: SizedBox(
                                  width: outW,
                                  child: _Output(
                                    stage: stage,
                                    child: _ResultsPaper(
                                      patient: merged,
                                      rows: rows,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _PillButton(
                              label: t3('تأكيد', 'پشتڕاستکردنەوە', 'Confirm'),
                              color: pal.accent,
                              textColor: Colors.white,
                              fontSize: 13,
                              onTap: app.closePrint,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _PillButton(
                              label: t3('إرسال', 'ناردن', 'Send'),
                              gradient: Fixed.sendGradient,
                              textColor: Colors.white,
                              icon: 'Send',
                              fontSize: 13,
                              onTap: () => app.openSendSheet(patient),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _PillButton(
                              label: backLabel,
                              color: pal.segmented,
                              fontSize: 13,
                              onTap: app.closePrint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Gradient? gradient;
  final Color? textColor;
  final String? icon;
  final double fontSize;

  const _PillButton({
    required this.label,
    required this.onTap,
    this.color,
    this.gradient,
    this.textColor,
    this.icon,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final tc = textColor ?? context.pal.ink;
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          gradient: gradient,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              LIcon(icon!, size: 15, color: tc),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: ts(context, fontSize, weight: w700, color: tc),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark printer body with status line and black screen.
class _Machine extends StatelessWidget {
  final String stage, status, title, trailing, sub;
  const _Machine({
    required this.stage,
    required this.status,
    required this.title,
    required this.trailing,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF3A3A3C)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, .55),
            offset: Offset(0, 20),
            blurRadius: 36,
            spreadRadius: -20,
          ),
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, .24),
            offset: Offset(0, 6),
            blurRadius: 14,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 44,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: _Status(stage: stage, text: status),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ts(
                                context,
                                13,
                                weight: w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            trailing,
                            textDirection: TextDirection.ltr,
                            style: ts(
                              context,
                              13,
                              weight: w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub,
                        textDirection: TextDirection.ltr,
                        textAlign: context.app.rtl
                            ? TextAlign.right
                            : TextAlign.left,
                        style: ts(
                          context,
                          11,
                          color: Colors.white.withValues(alpha: .6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // paper slot
          Positioned(
            left: 24,
            right: 24,
            bottom: 12,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Status extends StatefulWidget {
  final String stage, text;
  const _Status({required this.stage, required this.text});

  @override
  State<_Status> createState() => _StatusState();
}

class _StatusState extends State<_Status> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.stage == 'complete';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Center(
            child: done
                ? const LIcon(
                    'Check',
                    size: 18,
                    strokeWidth: 3,
                    color: Fixed.green,
                  )
                : RotationTransition(
                    turns: _spin,
                    child: CustomPaint(
                      size: const Size(18, 18),
                      painter: _SpinnerPainter(),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ts(
              context,
              12,
              weight: w500,
              color: Colors.white.withValues(alpha: .8),
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

/// `border-2 border-white/30 border-t-white rounded-full`
class _SpinnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(r, p..color = Colors.white.withValues(alpha: .3));
    canvas.drawArc(
      r,
      -3 * 3.14159 / 4,
      3.14159 / 2,
      false,
      p..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paper output: hidden while processing, fed in steps while printing.
class _Output extends StatefulWidget {
  final String stage;
  final Widget child;
  const _Output({required this.stage, required this.child});

  @override
  State<_Output> createState() => _OutputState();
}

class _OutputState extends State<_Output> with SingleTickerProviderStateMixin {
  late final AnimationController _feed = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1750),
  );

  // receiptFeed keyframes (linear): percent → translateY %
  static const _kf = <(double, double)>[
    (0, -100),
    (7.5, -91),
    (10.5, -91),
    (18, -81),
    (21, -81),
    (28.5, -70),
    (31.5, -70),
    (39, -58),
    (42, -58),
    (49.5, -45),
    (52.5, -45),
    (60, -32),
    (63, -32),
    (70.5, -20),
    (73.5, -20),
    (81, -10),
    (84, -10),
    (91.5, -3),
    (94.5, -3),
    (100, 0),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.stage == 'printing') _feed.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _Output old) {
    super.didUpdateWidget(old);
    if (widget.stage == 'printing' && old.stage != 'printing')
      _feed.forward(from: 0);
  }

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  double _y(double t) {
    final pct = t * 100;
    for (var i = 0; i < _kf.length - 1; i++) {
      final a = _kf[i], b = _kf[i + 1];
      if (pct <= b.$1) {
        final u = (pct - a.$1) / (b.$1 - a.$1);
        return a.$2 + (b.$2 - a.$2) * u;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    final visible = stage != 'processing';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 256),
      child: ClipRect(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedBuilder(
                animation: _feed,
                builder: (context, child) {
                  final pct = stage == 'complete'
                      ? 0.0
                      : stage == 'printing'
                      ? _y(_feed.value)
                      : -100.0;
                  return Opacity(
                    opacity: visible ? 1 : 0,
                    child: FractionalTranslation(
                      // first keyframe is calc(-100% + 2px); the 2px is negligible at this scale
                      translation: Offset(0, pct / 100),
                      child: child,
                    ),
                  );
                },
                child: _PaperShadow(child: widget.child),
              ),
            ),
            if (visible)
              Positioned(
                left: 24,
                right: 24,
                top: -4,
                child: IgnorePointer(
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, .75),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaperShadow extends StatelessWidget {
  final Widget child;
  const _PaperShadow({required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned(
        left: 12,
        right: 12,
        top: 12,
        bottom: 16,
        child: Container(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, .24),
                offset: Offset(0, 8),
                blurRadius: 24,
              ),
            ],
          ),
        ),
      ),
      child,
    ],
  );
}

/// The thermal-paper sheet (#fdfdf8, faint ruled lines, zig-zag bottom edge).
class _Paper extends StatelessWidget {
  final Widget child;
  const _Paper({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _ZigZagClipper(),
      child: CustomPaint(
        painter: _RuledPainter(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Color(0xFF111111)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _RuledPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFDFDF8),
    );
    final line = Paint()..color = const Color.fromRGBO(17, 17, 17, .05);
    for (double y = 23; y < size.height; y += 24) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// polygon(0 0, 100% 0, 100% calc(100% - 4px), …80 zig-zag points…)
class _ZigZagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const n = 80, tooth = 4.0;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - tooth);
    for (var r = 0; r < n; r++) {
      final x = size.width * (100 - (r + 1) * 100 / n) / 100;
      final y = r.isEven ? size.height : size.height - tooth;
      path.lineTo(x, y);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ---------------------------------------------------------------------------
// report content

const _qr = [
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  0,
  1,
  0,
  1,
  0,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  0,
  0,
  1,
  0,
  1,
  0,
  1,
  1,
  1,
  1,
  1,
  1,
  0,
  1,
  1,
  0,
  1,
  0,
  1,
  0,
  0,
  1,
  1,
  0,
  1,
  1,
  1,
  0,
  1,
  1,
  1,
  1,
  1,
  0,
  0,
  1,
  0,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  0,
];
const _bars = [
  3,
  1,
  2,
  1,
  3,
  2,
  1,
  2,
  3,
  1,
  2,
  1,
  3,
  2,
  1,
  2,
  3,
  1,
  2,
  3,
  1,
  2,
  1,
  3,
];

String formatToday(String lang) {
  final now = DateTime.now();
  const en = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sept',
    'Oct',
    'Nov',
    'Dec',
  ];
  const ar = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  final dd = now.day.toString().padLeft(2, '0');
  if (lang == 'ar') {
    String digits(String s) =>
        s.split('').map((c) => '٠١٢٣٤٥٦٧٨٩'[int.parse(c)]).join();
    return '${digits(dd)} ${ar[now.month - 1]} ${digits('${now.year}')}';
  }
  return '$dd ${en[now.month - 1]} ${now.year}';
}

class _ResultsPaper extends StatelessWidget {
  final Patient patient;
  final List<ResultRow> rows;
  const _ResultsPaper({required this.patient, required this.rows});

  TextStyle _m(
    BuildContext context,
    double size, {
    FontWeight weight = w400,
    Color? color,
    double height = 1.5,
    double? tracking,
  }) =>
      ts(
        context,
        size,
        weight: weight,
        color: color ?? const Color(0xFF111111),
        height: height,
        tracking: tracking,
      ).copyWith(
        fontFamily: 'Menlo',
        fontFamilyFallback: const [
          'SF Mono',
          'monospace',
          'Courier New',
          'Courier',
          'IBMPlexSansArabic',
        ],
      );

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final lang = app.lang;
    String t3(String ar, String ku, String en) => lang == 'ar'
        ? ar
        : lang == 'ku'
        ? ku
        : en;
    const faint = Color.fromRGBO(17, 17, 17, .6);

    final categories = <String>[];
    final byCat = <String, List<ResultRow>>{};
    for (final r in rows) {
      byCat
          .putIfAbsent(r.category, () {
            categories.add(r.category);
            return [];
          })
          .add(r);
    }

    final info = [
      (t3('المريض', 'نەخۆش', 'Patient'), patient.name),
      (t3('العمر', 'تەمەن', 'Age'), patient.age),
      (
        t3('الطبيب', 'پزیشک', 'Doctor'),
        patient.doctor.isEmpty ? '—' : patient.doctor,
      ),
      (
        t3('رقم المريض الدائم', 'ژمارەی هەمیشەیی نەخۆش', 'Patient No.'),
        patient.permanent,
      ),
      (t3('التاريخ', 'بەروار', 'Date'), formatToday(lang)),
      (t3('الجنس', 'ڕەگەز', 'Gender'), patient.gender),
    ];

    Widget infoCell((String, String) e) => Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFF5F5F4),
      child: Row(
        children: [
          Text(
            e.$1,
            style: _m(
              context,
              9,
              weight: w700,
              color: const Color.fromRGBO(17, 17, 17, .55),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              e.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: _m(context, 10, weight: w700),
            ),
          ),
        ],
      ),
    );

    const cols = [38, 18, 14, 20, 10];
    Widget gridRow(
      List<Widget> cells, {
      Color? bg,
      Border? border,
      double h = 28,
    }) => Container(
      height: h,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: bg, border: border),
      child: Row(
        children: [
          for (var i = 0; i < 5; i++) Expanded(flex: cols[i], child: cells[i]),
        ],
      ),
    );

    return _Paper(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/logo.jpg',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'LabGo',
            style: _m(
              context,
              17,
              weight: w900,
              height: 1,
              tracking: -0.025 * 17,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            app.labName,
            textAlign: TextAlign.center,
            style: _m(context, 11, weight: w700, height: 1.25),
          ),
          const SizedBox(height: 4),
          Text(
            app.labPhone,
            textDirection: TextDirection.ltr,
            style: _m(context, 9, height: 1.25),
          ),
          Text(
            app.labAddress,
            textAlign: TextAlign.center,
            style: _m(context, 9, height: 1.25),
          ),
          const SizedBox(height: 8),
          Text(
            t3('تقرير النتائج', 'ڕاپۆرتی ئەنجامەکان', 'Lab Results Report'),
            style: _m(context, 11, weight: w900, tracking: .025 * 11),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0xFF111111)),
          const SizedBox(height: 12),
          // 2-column info grid with 1px gaps
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE2E2E2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E2E2)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < info.length; i += 2) ...[
                  if (i > 0) const SizedBox(height: 1),
                  Row(
                    children: [
                      Expanded(child: infoCell(info[i])),
                      const SizedBox(width: 1),
                      Expanded(child: infoCell(info[i + 1])),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final cat in categories) ...[
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFD9D9D9)),
              ),
              child: Column(
                children: [
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    color: const Color(0xFF2B2B2E),
                    child: Row(
                      children: [
                        Text(
                          categoryArabic(cat),
                          style: _m(
                            context,
                            10,
                            weight: w700,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          cat,
                          textDirection: TextDirection.ltr,
                          style: _m(
                            context,
                            10,
                            weight: w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  gridRow(
                    [
                      Text(
                        t3('الفحص', 'پشکنین', 'Test'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _m(context, 9, weight: w900),
                      ),
                      Text(
                        t3('النتيجة', 'ئەنجام', 'Result'),
                        textAlign: TextAlign.center,
                        style: _m(context, 9, weight: w900),
                      ),
                      Text(
                        t3('الوحدة', 'یەکە', 'Unit'),
                        textAlign: TextAlign.center,
                        style: _m(context, 9, weight: w900),
                      ),
                      Text(
                        t3('الطبيعي', 'ئاسایی', 'Normal'),
                        textAlign: TextAlign.center,
                        style: _m(context, 9, weight: w900),
                      ),
                      Text(
                        t3('الحالة', 'دۆخ', 'Status'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: _m(context, 9, weight: w900),
                      ),
                    ],
                    bg: const Color(0xFFEEEEEE),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFD9D9D9)),
                    ),
                  ),
                  for (final r in byCat[cat]!)
                    () {
                      final c = classify(r.value, r.normalRow);
                      final dot = c == 'low'
                          ? Fixed.blue
                          : c == 'high'
                          ? Fixed.red
                          : c == 'normal'
                          ? Fixed.green
                          : const Color(0xFF999999);
                      return gridRow(
                        [
                          Text(
                            r.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _m(context, 10, weight: w700),
                          ),
                          Text(
                            r.value.isEmpty ? '—' : r.value,
                            textAlign: TextAlign.center,
                            style: _m(context, 10, weight: w700),
                          ),
                          Text(
                            r.units,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: _m(context, 10),
                          ),
                          Text(
                            r.range,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.ltr,
                            style: _m(context, 10),
                          ),
                          Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: dot,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                        border: const Border(
                          bottom: BorderSide(color: Color(0xFFE8E8E8)),
                        ),
                      );
                    }(),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(height: 1, color: const Color(0xFF111111)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // w-[86px] but allowed to shrink like a CSS flex item
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 86),
                  child: Column(
                    children: [
                      Container(height: 1, color: const Color(0xFF111111)),
                      const SizedBox(height: 4),
                      Text(
                        t3('توقيع الطبيب', 'واژووی پزیشک', 'Doctor signature'),
                        textAlign: TextAlign.center,
                        style: _m(context, 8, color: faint),
                      ),
                      if (patient.doctor.isNotEmpty)
                        Text(
                          patient.doctor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _m(context, 9, weight: w700),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  _Barcode(height: (i) => 15 + (i * 7) % 16),
                  const SizedBox(height: 4),
                  Text(
                    patient.permanent,
                    style: _m(context, 7, color: faint, tracking: .12 * 7),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  const _QrBox(size: 48),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 48,
                    child: Text(
                      t3(
                        'امسح لعرض النتيجة',
                        'سکان بکە بۆ بینینی ئەنجام',
                        'Scan for result',
                      ),
                      textAlign: TextAlign.center,
                      style: _m(context, 7, color: faint),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'THANK YOU • LabGo',
            textAlign: TextAlign.center,
            style: _m(context, 10, weight: w900, tracking: .1 * 10),
          ),
          Text(
            app.labFooter,
            textAlign: TextAlign.center,
            style: _m(context, 8, color: faint),
          ),
        ],
      ),
    );
  }
}

class _Barcode extends StatelessWidget {
  final double Function(int i) height;
  const _Barcode({required this.height});

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFF111111)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < _bars.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            width: _bars[i].toDouble(),
            height: height(i),
            color: const Color(0xFF111111),
          ),
        ],
      ],
    ),
  );
}

class _QrBox extends StatelessWidget {
  final double size;
  const _QrBox({required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFF111111)),
    ),
    child: LayoutBuilder(
      builder: (context, c) {
        final cell = (c.maxWidth - 7) / 8;
        return Wrap(
          spacing: 1,
          runSpacing: 1,
          children: [
            for (var i = 0; i < 64; i++)
              Container(
                width: cell,
                height: cell,
                color: _qr[i] == 1 ? const Color(0xFF111111) : Colors.white,
              ),
          ],
        );
      },
    ),
  );
}
