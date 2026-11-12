/// Sample data copied from the design (patients, test catalog, packages).
/// Phase 1 is UI-only: nothing here talks to the server.

class RangeRow {
  final String ageFrom, ageTo, ageUnit, gender, min, max;
  const RangeRow(
    this.ageFrom,
    this.ageTo,
    this.ageUnit,
    this.gender,
    this.min,
    this.max,
  );
}

class CatalogTest {
  final String name;
  final int price, priceB2B;
  final String category;
  final bool on;
  final String units;
  final String normalText;
  final List<RangeRow> ranges;
  const CatalogTest({
    required this.name,
    required this.price,
    required this.priceB2B,
    required this.category,
    required this.on,
    required this.units,
    this.normalText = '',
    required this.ranges,
  });
}

class LabPackage {
  final String id, code, name, category;
  final List<String> aliases, tests;
  final int price, priceB2B;
  final bool active;
  const LabPackage({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.aliases,
    required this.tests,
    required this.price,
    required this.priceB2B,
    required this.active,
  });
}

class Patient {
  final String id,
      name,
      age,
      gender,
      phone,
      sample,
      urgency,
      notes,
      status,
      time,
      doctor,
      mode,
      permanent;
  final String? company;
  final List<String> tests;
  final List<String> packages;
  final int price;
  final Map<String, String> results;
  const Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    required this.tests,
    required this.sample,
    required this.urgency,
    required this.notes,
    required this.status,
    required this.time,
    required this.price,
    required this.doctor,
    required this.mode,
    required this.results,
    required this.permanent,
    this.company,
    this.packages = const [],
  });

  Patient copyWith({Map<String, String>? results, String? status}) => Patient(
    id: id,
    name: name,
    age: age,
    gender: gender,
    phone: phone,
    tests: tests,
    sample: sample,
    urgency: urgency,
    notes: notes,
    status: status ?? this.status,
    time: time,
    price: price,
    doctor: doctor,
    mode: mode,
    results: results ?? this.results,
    permanent: permanent,
    company: company,
    packages: packages,
  );
}

const kPatientsSeed = <Patient>[
  Patient(
    id: 'seed-1',
    name: 'Ali Ahmed',
    age: '32Y',
    gender: 'Male',
    phone: '+964 770 000 0000',
    tests: ['CBC', 'Sugar'],
    sample: 'Blood',
    urgency: 'Normal',
    notes: '',
    status: 'Completed',
    time: '09:12',
    price: 25000,
    doctor: 'Dr. Ahmed',
    mode: 'B2C',
    results: {'CBC': '13.2', 'Sugar': '110'},
    permanent: 'P-2026-0842',
  ),
  Patient(
    id: 'seed-2',
    name: 'Sara Ali',
    age: '28Y',
    gender: 'Female',
    phone: '+964 770 000 0001',
    tests: ['Vitamin D'],
    sample: 'Blood',
    urgency: 'Normal',
    notes: '',
    status: 'Pending',
    time: '10:05',
    price: 40000,
    doctor: 'Dr. Sara',
    mode: 'B2C',
    results: {'Vitamin D': '18'},
    permanent: 'P-2026-0843',
  ),
  Patient(
    id: 'seed-3',
    name: 'Omar Yousef',
    age: '41Y',
    gender: 'Male',
    phone: '+964 770 000 0002',
    tests: ['Hormone'],
    sample: 'Blood',
    urgency: 'Urgent',
    notes: '',
    status: 'Sent',
    time: '11:20',
    price: 60000,
    doctor: 'Dr. Omar',
    mode: 'B2B',
    company: 'Al-Noor Clinic',
    results: {'Hormone': '520'},
    permanent: 'P-2026-0844',
  ),
  Patient(
    id: 'seed-4',
    name: 'Layla Hassan',
    age: '35Y',
    gender: 'Female',
    phone: '+964 770 000 0003',
    tests: ['Sugar'],
    sample: 'Blood',
    urgency: 'Normal',
    notes: '',
    status: 'Completed',
    time: '12:00',
    price: 10000,
    doctor: 'Dr. Ahmed',
    mode: 'B2C',
    results: {'Sugar': '95'},
    permanent: 'P-2026-0845',
  ),
];

/// Initials: "Ali Ahmed" -> "AA" (design function `tl`).
String initials(String name) => name
    .split(' ')
    .where((s) => s.isNotEmpty)
    .map((s) => s[0])
    .take(2)
    .join()
    .toUpperCase();
