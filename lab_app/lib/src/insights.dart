import 'app_state.dart';

/// One bar of a home insight chart.
class InsightBar {
  final String label;
  final int count;
  const InsightBar(this.label, this.count);
}

/// Home insight cards, counted from the lab's real patients (by registration date).
extension HomeInsights on AppState {
  List<DateTime> get _dates => [for (final p in patients) if (p.createdAt != null) p.createdAt!.toLocal()];

  List<String> get _months => lang == 'en'
      ? const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
      : const ['كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران', 'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول'];

  /// The last 12 months, oldest first (the last bar is this month).
  List<InsightBar> get monthlyBars {
    final now = DateTime.now();
    final counts = List<int>.filled(12, 0);
    for (final d in _dates) {
      final back = (now.year - d.year) * 12 + now.month - d.month;
      if (back >= 0 && back < 12) counts[11 - back]++;
    }
    return [
      for (var i = 0; i < 12; i++) InsightBar(_months[(now.month + i) % 12], counts[i]),
    ];
  }

  /// Index of the busiest bar, or -1 when every bar is empty.
  int peakIndex(List<InsightBar> bars) {
    var best = -1, max = 0;
    for (var i = 0; i < bars.length; i++) {
      if (bars[i].count > max) {
        max = bars[i].count;
        best = i;
      }
    }
    return best;
  }

  /// This month against last month, in percent; null when last month had none.
  int? get monthGrowth {
    final b = monthlyBars;
    final last = b[10].count, cur = b[11].count;
    if (last == 0) return null;
    return ((cur - last) * 100 / last).round();
  }

  String get growthLabel {
    final g = monthGrowth;
    if (g == null) {
      return monthlyBars[11].count == 0
          ? tr('لا مرضى هذا الشهر بعد', 'هێشتا نەخۆش نییە', 'No patients this month yet')
          : tr('أول شهر للمقارنة', 'یەکەم مانگ', 'First month to compare');
    }
    final s = g >= 0 ? '+$g%' : '$g%';
    return tr('النمو $s عن الشهر الماضي', 'گەشە $s', 'Growth $s vs last month');
  }

  String get bestMonthLabel {
    final b = monthlyBars, i = peakIndex(b);
    if (i < 0) return tr('لا بيانات بعد', 'داتا نییە', 'No data yet');
    return tr('أفضل شهر: ${b[i].label}', 'باشترین مانگ: ${b[i].label}', 'Best month: ${b[i].label}');
  }

  String get totalYearLabel {
    final n = monthlyBars.fold<int>(0, (a, b) => a + b.count);
    return tr('إجمالي $n مريض خلال 12 شهراً', 'کۆی $n نەخۆش', 'Total $n patients in 12 months');
  }

  /// Peak chart for 'Day' (by hour, last 30 days), 'Week' (by weekday, last 8 weeks),
  /// 'Month' (by month, this year) and 'Year' (last 5 years).
  List<InsightBar> peakBars(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'Day':
        final from = now.subtract(const Duration(days: 30));
        final hours = List<int>.filled(24, 0);
        for (final d in _dates) {
          if (d.isAfter(from)) hours[d.hour]++;
        }
        // Working hours 8:00–21:00 plus any busy hour outside them.
        final last = hours.lastIndexWhere((c) => c > 0);
        final a = _firstHour, b = last > 20 ? last : 20;
        return [for (var h = a; h <= b; h++) InsightBar(_hour(h), hours[h])];
      case 'Week':
        final from = now.subtract(const Duration(days: 56));
        final days = List<int>.filled(7, 0); // Sunday first
        for (final d in _dates) {
          if (d.isAfter(from)) days[d.weekday % 7]++;
        }
        final names = lang == 'en'
            ? const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            : const ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
        return [for (var i = 0; i < 7; i++) InsightBar(names[i], days[i])];
      case 'Month':
        final m = List<int>.filled(12, 0);
        for (final d in _dates) {
          if (d.year == now.year) m[d.month - 1]++;
        }
        return [for (var i = 0; i < now.month; i++) InsightBar(_months[i], m[i])];
      default:
        final y = <int, int>{for (var i = now.year - 4; i <= now.year; i++) i: 0};
        for (final d in _dates) {
          if (y.containsKey(d.year)) y[d.year] = y[d.year]! + 1;
        }
        return [for (final e in y.entries) InsightBar('${e.key}', e.value)];
    }
  }

  String _hour(int h) {
    if (lang == 'en') return h == 0 ? '12am' : h < 12 ? '${h}am' : h == 12 ? '12pm' : '${h - 12}pm';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12${h < 12 ? 'ص' : 'م'}';
  }

  String peakLabel(String period) {
    final bars = peakBars(period), i = peakIndex(bars);
    if (i < 0) return tr('لا بيانات بعد', 'داتا نییە', 'No data yet');
    // Day bars start at _firstHour, one bar per hour.
    final v = period == 'Day' ? '${bars[i].label}–${_hour((_firstHour + i + 1) % 24)}' : bars[i].label;
    return tr('الذروة $v', 'لووتکە $v', 'Peak $v');
  }

  int get _firstHour {
    final from = DateTime.now().subtract(const Duration(days: 30));
    var first = 8;
    for (final d in _dates) {
      if (d.isAfter(from) && d.hour < first) first = d.hour;
    }
    return first;
  }

  String peakSub(String period) {
    final bars = peakBars(period), i = peakIndex(bars);
    if (i < 0) return tr('تظهر بعد تسجيل المرضى', 'دوای تۆمارکردن', 'Shows once patients are added');
    final scope = switch (period) {
      'Day' => tr('آخر 30 يوماً', '٣٠ ڕۆژ', 'last 30 days'),
      'Week' => tr('آخر 8 أسابيع', '٨ هەفتە', 'last 8 weeks'),
      'Month' => tr('هذه السنة', 'ئەمساڵ', 'this year'),
      _ => tr('آخر 5 سنوات', '٥ ساڵ', 'last 5 years'),
    };
    return tr('${bars[i].count} مريض • $scope', '${bars[i].count} نەخۆش • $scope', '${bars[i].count} patients • $scope');
  }
}
