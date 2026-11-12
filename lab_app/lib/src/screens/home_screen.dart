import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../ui.dart';

/// "Reports" tab: header, swipeable stats card, search, filters and recent reports.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final labReports = app.w('labReports');
    final reportsWord = labReports.split(' - ').length > 1
        ? labReports.split(' - ')[1]
        : labReports;
    final list = app.homeList;

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
          if (app.guest)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: pal.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      app.tr(
                        'أنت تتصفح كضيف',
                        'وەک میوان دەگەڕێیت',
                        'You are browsing as a guest',
                      ),
                      style: ts(context, 13, weight: w700, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tap(
                    onTap: () {
                      app.guest = false;
                      app.logout();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: pal.white, // bg-white (dark: #1C1C1E)
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        app.tr('تسجيل الدخول', 'چوونە ژوورەوە', 'Log In'),
                        style: ts(
                          context,
                          12,
                          weight: w900,
                          color: pal.dark
                              ? Colors.white
                              : const Color(0xFF111111),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            app.w('date'),
            style: ts(context, 14, weight: w500, color: pal.muted),
          ),
          Text(
            '${app.labDisplayName} — $reportsWord',
            style: ts(
              context,
              30,
              weight: w700,
              height: 34 / 30,
              tracking: -0.02 * 30,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${app.w('greeting')} • ${app.doctorName}',
            style: ts(context, 15, color: pal.muted2),
          ),
          const SizedBox(height: 12),
          const Entrance.fadeUp(child: _StatsCard()),
          const SizedBox(height: 8),
          const _CardDots(),
          const SizedBox(height: 12),
          SearchBarBox(
            hint: app.w('search'),
            iconSize: 17,
            onChanged: app.setHomeSearch,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in const [
                  'All',
                  'Pending',
                  'Completed',
                  'Sent',
                ]) ...[
                  if (f != 'All') const SizedBox(width: 8),
                  FilterChipPill(
                    label: f == 'All'
                        ? app.w('all')
                        : f == 'Pending'
                        ? app.w('pending')
                        : f == 'Completed'
                        ? app.w('completed')
                        : app.w('sentFilter'),
                    selected: app.homeFilter == f,
                    onTap: () => app.setHomeFilter(f),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(app.w('recent'), style: ts(context, 17, weight: w700)),
          const SizedBox(height: 12),
          for (final p in list) ...[
            ReportRow(patient: p, onTap: () => app.openPatient(p)),
            const SizedBox(height: 12),
          ],
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                app.w('search'),
                textAlign: TextAlign.center,
                style: ts(context, 13, color: pal.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// A patient row card (used on Reports).
class ReportRow extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;
  const ReportRow({super.key, required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    return Tap(
      onTap: onTap,
      child: CardBox(
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
                    '${patient.tests.join(', ')} ${patient.status == 'Sent' ? '• ${app.w('sentTo')}' : ''}',
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
                Text(patient.time, style: ts(context, 12, color: pal.muted)),
                StatusPill(patient.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardDots extends StatelessWidget {
  const _CardDots();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    Widget arrow(String icon, VoidCallback onTap) => Tap(
      onTap: onTap,
      scale: .9,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: pal.chipBg, shape: BoxShape.circle),
        child: LIcon(icon, size: 16, color: pal.ink),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        arrow('ChevronLeft', () => app.goCard(app.card - 1)),
        const SizedBox(width: 8),
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          GestureDetector(
            onTap: () => app.goCard(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: const Cubic(0.4, 0, 0.2, 1),
              width: i == app.card ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == app.card ? pal.accent : pal.track,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        arrow('ChevronRight', () => app.goCard(app.card + 1)),
      ],
    );
  }
}

/// The 230px card that flips between 4 stat views (swipe or arrows).
class _StatsCard extends StatefulWidget {
  const _StatsCard();

  @override
  State<_StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<_StatsCard>
    with SingleTickerProviderStateMixin {
  Offset? _start;
  Offset _drag = Offset.zero;

  // animated counters (design: dh / Ae, 600ms ease-out-cubic)
  static const _totals = [(24, 18), (142, 121), (586, 512)];
  late final AnimationController _count = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  int _fromPatients = 24,
      _fromReports = 18,
      _toPatients = 24,
      _toReports = 18,
      _period = 0;

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  void _syncPeriod(int period) {
    if (period == _period) return;
    final t = Curves.easeOutCubic.transform(_count.value);
    _fromPatients = (_fromPatients + (_toPatients - _fromPatients) * t).round();
    _fromReports = (_fromReports + (_toReports - _fromReports) * t).round();
    _toPatients = _totals[period].$1;
    _toReports = _totals[period].$2;
    _period = period;
    _count.forward(from: 0);
  }

  void _end() {
    final app = context.app;
    final d = _drag;
    setState(() {
      _start = null;
      _drag = Offset.zero;
    });
    final ax = d.dx.abs(), ay = d.dy.abs();
    if (math.max(ax, ay) < 40) return;
    if (ax >= ay) {
      app.goCard(d.dx < 0 ? app.card + 1 : app.card - 1);
    } else {
      app.goCard(d.dy < 0 ? app.card + 1 : app.card - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    _syncPeriod(app.period);
    final dragging = _start != null;

    final m = Matrix4.identity()..setEntry(3, 2, 1 / 900);
    if (dragging) {
      final dx = _drag.dx;
      m
        ..translateByDouble(dx * .25, _drag.dy * .12, 0, 1)
        ..rotateY(dx * .22 * math.pi / 180)
        ..scaleByDouble(
          1 - math.min(.06, dx.abs() / 1200),
          1 - math.min(.06, dx.abs() / 1200),
          1,
          1,
        );
    }

    final card = GestureDetector(
      onPanStart: (d) => setState(() {
        _start = d.globalPosition;
        _drag = Offset.zero;
      }),
      onPanUpdate: (d) => setState(() => _drag = d.globalPosition - _start!),
      onPanEnd: (_) => _end(),
      onPanCancel: _end,
      child: Container(
        height: 230,
        padding: const EdgeInsets.all(16),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: pal.cardBorder),
          boxShadow: Shadows.sm,
        ),
        child: AnimatedBuilder(
          animation: _count,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_count.value);
            final patients = (_fromPatients + (_toPatients - _fromPatients) * t)
                .round();
            final reports = (_fromReports + (_toReports - _fromReports) * t)
                .round();
            return _cardContent(context, app.card, patients, reports);
          },
        ),
      ),
    );

    if (dragging)
      return Transform(alignment: Alignment.center, transform: m, child: card);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: app.cardFlipping ? 1 : 0),
      duration: const Duration(milliseconds: 380),
      curve: const Cubic(.34, 1.3, .64, 1),
      builder: (context, v, child) {
        final rot = Matrix4.identity()
          ..setEntry(3, 2, 1 / 900)
          ..rotateY(v * math.pi / 2);
        return Transform(
          alignment: Alignment.center,
          transform: rot,
          child: child,
        );
      },
      child: AnimatedOpacity(
        opacity: app.cardFlipping ? 0 : 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
        child: card,
      ),
    );
  }

  Widget _pill(BuildContext context, String text, {bool active = false}) {
    final pal = context.pal;
    return Expanded(
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Fixed.orange : pal.chipBg,
          borderRadius: BorderRadius.circular(999),
          border: active ? null : Border.all(color: pal.line),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          style: ts(
            context,
            11,
            weight: w700,
            color: active ? Colors.white : pal.muted2,
          ),
        ),
      ),
    );
  }

  Widget _pills(BuildContext context, List<String> labels, int activeIndex) =>
      SizedBox(
        height: 28,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _pill(context, labels[i], active: i == activeIndex),
            ],
          ],
        ),
      );

  Widget _headerRow(BuildContext context, Widget start, Widget end) => SizedBox(
    height: 32,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [start, const SizedBox(width: 8), end],
    ),
  );

  Widget _bigStat(
    BuildContext context,
    String label,
    String value,
    String sub, {
    double size = 48,
    bool gap = false,
  }) {
    final pal = context.pal;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ts(context, 13, color: pal.muted, height: 1.1),
        ),
        if (gap) const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          style: ts(context, size, weight: w900, height: 1.1),
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ts(context, 13, color: pal.muted, height: 1.1),
        ),
      ],
    );
  }

  Widget _title(BuildContext context, String text) => Flexible(
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: ts(context, 15, weight: w700),
    ),
  );

  Widget _faint(BuildContext context, String text) => Opacity(
    opacity: .7,
    child: Text(
      text,
      maxLines: 1,
      style: ts(context, 11, color: context.pal.muted),
    ),
  );

  Widget _cardContent(
    BuildContext context,
    int index,
    int patients,
    int reports,
  ) {
    final app = context.app;
    final pal = app.palette;
    final d = app.d, w = app.w;
    Widget body;
    switch (index) {
      case 0:
        final label = app.period == 0
            ? d('patientsToday')
            : app.period == 1
            ? d('patientsWeekly')
            : d('patientsMonthly');
        body = Column(
          children: [
            _headerRow(
              context,
              Tap(
                onTap: app.cyclePeriod,
                scale: .95,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: pal.chipBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LIcon('FlaskConical', size: 13, color: pal.accent),
                      const SizedBox(width: 6),
                      Text(
                        w('todayReports'),
                        style: ts(context, 12, weight: w700),
                      ),
                    ],
                  ),
                ),
              ),
              Flexible(child: _faint(context, '${d('tapToCycle')} ↻')),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: Row(
                children: [
                  Expanded(
                    child: _bigStat(
                      context,
                      label,
                      '$patients',
                      '$reports ${w('todayReports').toLowerCase()}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.flip(
                                flipX: app.rtl,
                                child: CustomPaint(
                                  size: const Size(84, 84),
                                  painter: _Donut(
                                    track: pal.track,
                                    color: pal.accent,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$reports',
                                    style: ts(
                                      context,
                                      24,
                                      weight: w900,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    w('completed'),
                                    style: ts(
                                      context,
                                      10,
                                      color: pal.muted,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _legend(
                                context,
                                pal.muted,
                                '${w('completed')} $reports',
                              ),
                              const SizedBox(height: 6),
                              _legend(
                                context,
                                Fixed.orange,
                                '${w('pending')} 4',
                              ),
                              const SizedBox(height: 6),
                              _legend(
                                context,
                                pal.muted,
                                '${w('sentShort')} 2',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _pills(context, [
              '${w('completed')} $reports',
              '${w('pending')} 4',
              '${w('sentShort')} 2',
            ], 1),
          ],
        );
      case 1:
        const bars = [32, 38, 29, 41, 45, 39, 48, 52, 47, 68, 55, 58];
        body = Column(
          children: [
            _headerRow(
              context,
              _title(context, d('monthlyReports')),
              _faint(context, d('totalReports')),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: Row(
                children: [
                  Expanded(
                    child: _bigStat(
                      context,
                      d('bestMonth'),
                      '512',
                      d('monthlyReports'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 84,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < bars.length; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Expanded(
                              child: Container(
                                height: bars[i] / 68 * 84,
                                decoration: BoxDecoration(
                                  color: i == 9 ? pal.accent : pal.track,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _pills(context, [
              d('bestMonth'),
              d('totalReports'),
              d('growthText'),
            ], 1),
          ],
        );
      case 2:
        body = Column(
          children: [
            _headerRow(
              context,
              _title(context, d('growthByMonth')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pal.chipBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: pal.line),
                ),
                child: Text(
                  d('growthText'),
                  style: ts(
                    context,
                    11,
                    weight: w700,
                    color: pal.muted2,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: Row(
                children: [
                  Expanded(
                    child: _bigStat(
                      context,
                      d('growthByMonth'),
                      '+18%',
                      d('bestMonth'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 84,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1100),
                        curve: Curves.easeOut,
                        builder: (context, t, _) => CustomPaint(
                          size: Size.infinite,
                          painter: _GrowthLine(
                            color: pal.accent,
                            card: pal.card,
                            t: t,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _pills(context, [
              d('growthText'),
              d('bestMonth'),
              d('totalReports'),
            ], 1),
          ],
        );
      default:
        final peak = app.peak;
        final peakValue = peak == 'Day'
            ? d('peakDay')
            : peak == 'Week'
            ? d('peakWeek')
            : peak == 'Month'
            ? d('peakMonth')
            : d('peakYear');
        final periodLabel = peak == 'Day'
            ? d('day')
            : peak == 'Week'
            ? d('week')
            : peak == 'Month'
            ? d('month')
            : d('year');
        const heights = [30, 55, 95, 70, 40];
        body = Column(
          children: [
            _headerRow(
              context,
              _title(context, d('peakPeriod')),
              _faint(context, periodLabel),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: Row(
                children: [
                  Expanded(
                    child: _bigStat(
                      context,
                      d('peakPeriod'),
                      peakValue,
                      d('growthText'),
                      size: 22,
                      gap: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 84,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < heights.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Opacity(
                              opacity: i == 2 ? 1 : .45,
                              child: Container(
                                width: 32,
                                height: 84 * heights[i] / 100,
                                decoration: BoxDecoration(
                                  color: pal.accent,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 28,
              child: Row(
                children: [
                  for (final p in const ['Day', 'Week', 'Month', 'Year']) ...[
                    if (p != 'Day') const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => app.setPeak(p),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: peak == p ? pal.ink : pal.chipBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            p == 'Day'
                                ? d('day')
                                : p == 'Week'
                                ? d('week')
                                : p == 'Month'
                                ? d('month')
                                : d('year'),
                            maxLines: 1,
                            style: ts(
                              context,
                              11,
                              weight: w700,
                              color: peak == p
                                  ? (pal.dark
                                        ? const Color(0xFF0B0B0D)
                                        : pal.appBg)
                                  : pal.muted2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
    }
    return body;
  }

  Widget _legend(BuildContext context, Color dot, String text) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: ts(context, 12, height: 1.25),
        ),
      ),
    ],
  );
}

/// Donut ring: r=40, stroke 11 on a 100 viewBox, 75% filled, starting at 12 o'clock.
class _Donut extends CustomPainter {
  final Color track, color;
  _Donut({required this.track, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final c = Offset(size.width / 2, size.height / 2);
    final r = 40 * s;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11 * s;
    canvas.drawCircle(c, r, p..color = track);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * .75,
      false,
      p
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _Donut old) =>
      old.track != track || old.color != color;
}

/// Growth line from the design's SVG (viewBox 320x118, preserveAspectRatio none).
class _GrowthLine extends CustomPainter {
  final Color color, card;
  final double t;
  _GrowthLine({required this.color, required this.card, required this.t});

  static const _pts = [
    Offset(0, 100),
    Offset(40, 92),
    Offset(80, 84),
    Offset(120, 78),
    Offset(160, 62),
    Offset(200, 58),
    Offset(240, 44),
    Offset(280, 30),
    Offset(320, 18),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // preserveAspectRatio="none": scale user space non-uniformly, strokes included.
    canvas.save();
    canvas.scale(size.width / 320, size.height / 118);
    canvas.clipRect(
      const Rect.fromLTWH(0, 0, 320, 118),
    ); // svg overflow: hidden
    final path = Path()..moveTo(_pts[0].dx, _pts[0].dy);
    for (final p in _pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final metric = path.computeMetrics().first;
    // stroke-dasharray:520 with dashoffset 520→0 reveals 520·t user units.
    final shown = math.min(metric.length, 520 * t);
    canvas.drawPath(
      metric.extractPath(0, shown),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(const Offset(320, 18), 5, Paint()..color = color);
    canvas.drawCircle(
      const Offset(320, 18),
      5,
      Paint()
        ..color = card
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GrowthLine old) =>
      old.t != t || old.color != color;
}
