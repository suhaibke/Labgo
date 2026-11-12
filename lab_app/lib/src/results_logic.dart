import 'catalog_data.dart';
import 'models.dart';

/// Port of the design's result helpers (Aw, EA, yw, G6, vw, cw, q6).

double _ageDays(String age) {
  final m = RegExp(
    r'(\d+(?:\.\d+)?)\s*([YMD])',
    caseSensitive: false,
  ).firstMatch(age);
  if (m == null) return 10950;
  final v = double.parse(m.group(1)!);
  final u = m.group(2)!.toUpperCase();
  return u == 'Y'
      ? v * 365
      : u == 'M'
      ? v * 30
      : v;
}

double _toDays(String n, String unit) {
  final v = double.tryParse(n) ?? 0;
  return unit == 'Y'
      ? v * 365
      : unit == 'M'
      ? v * 30
      : v;
}

RangeRow? normalRowFor(CatalogTest? test, Patient p) {
  if (test == null || test.ranges.isEmpty) return null;
  final age = _ageDays(p.age);
  final g = p.gender == 'Female' ? 'Female' : 'Male';
  bool inAge(RangeRow r) =>
      age >= _toDays(r.ageFrom, r.ageUnit) &&
      age <= _toDays(r.ageTo, r.ageUnit);
  for (final r in test.ranges) {
    if ((r.gender == 'Both' || r.gender == g) && inAge(r)) return r;
  }
  for (final r in test.ranges) {
    if (inAge(r)) return r;
  }
  return test.ranges.first;
}

/// Returns 'low' | 'high' | 'normal' | null.
String? classify(String value, RangeRow? row) {
  if (value.trim().isEmpty || row == null) return null;
  final v = double.tryParse(value.trim());
  if (v == null) return null;
  final mn = double.tryParse(row.min);
  final mx = double.tryParse(row.max);
  if (mn != null && v < mn) return 'low';
  if (mx != null && v > mx) return 'high';
  return 'normal';
}

String _categoryFor(Patient p, String test) {
  if (p.packages.isNotEmpty) {
    for (final pk in kPackages) {
      if (p.packages.contains(pk.id) || p.packages.contains(pk.name))
        return pk.category;
    }
  }
  for (final c in kCatalog) {
    if (c.name == test) return c.category;
  }
  return 'General';
}

String categoryArabic(String c) =>
    const {
      'Lipid': 'الدهون',
      'Diabetes': 'السكري',
      'Thyroid': 'الغدة',
      'General': 'عام',
      'Vitamins': 'الفيتامينات',
      'Hormones': 'الهرمونات',
      'Hair Loss': 'تساقط الشعر',
      'Full Checkup': 'فحص شامل',
      'Offer': 'العرض',
    }[c] ??
    c;

class ResultRow {
  final String test, value, units, range, label, category;
  final RangeRow? normalRow;
  const ResultRow(
    this.test,
    this.value,
    this.units,
    this.range,
    this.label,
    this.category,
    this.normalRow,
  );
}

List<ResultRow> resultRows(Patient p) {
  return [
    for (final t in p.tests)
      () {
        CatalogTest? c;
        for (final x in kCatalog) {
          if (x.name == t) c = x;
        }
        final row = normalRowFor(c, p);
        final range = (c != null && c.normalText.trim().isNotEmpty)
            ? c.normalText
            : '${row?.min ?? '—'}-${row?.max ?? '—'}';
        return ResultRow(
          t,
          p.results[t] ?? '',
          c?.units ?? '',
          range,
          t,
          _categoryFor(p, t),
          row,
        );
      }(),
  ];
}
