import 'dart:typed_data';

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

  RangeRow copyWith({
    String? ageFrom,
    String? ageTo,
    String? ageUnit,
    String? gender,
    String? min,
    String? max,
  }) => RangeRow(
    ageFrom ?? this.ageFrom,
    ageTo ?? this.ageTo,
    ageUnit ?? this.ageUnit,
    gender ?? this.gender,
    min ?? this.min,
    max ?? this.max,
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

  CatalogTest copyWith({
    int? price,
    int? priceB2B,
    String? category,
    bool? on,
    String? units,
    String? normalText,
    List<RangeRow>? ranges,
  }) => CatalogTest(
    name: name,
    price: price ?? this.price,
    priceB2B: priceB2B ?? this.priceB2B,
    category: category ?? this.category,
    on: on ?? this.on,
    units: units ?? this.units,
    normalText: normalText ?? this.normalText,
    ranges: ranges ?? this.ranges,
  );
}

class LabPackage {
  final String id, code, name, category;
  final List<String> aliases, tests;
  final int price, priceB2B;
  final bool active;
  final bool isOffer;
  final int oldPrice;
  final String startDate, endDate;
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
    this.isOffer = false,
    this.oldPrice = 0,
    this.startDate = '',
    this.endDate = '',
  });

  LabPackage copyWith({bool? active}) => LabPackage(
    id: id,
    code: code,
    name: name,
    category: category,
    aliases: aliases,
    tests: tests,
    price: price,
    priceB2B: priceB2B,
    active: active ?? this.active,
    isOffer: isOffer,
    oldPrice: oldPrice,
    startDate: startDate,
    endDate: endDate,
  );
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
  final String? packageCategory;
  final List<String> tests;
  final List<String> packages;
  final int price;
  final Map<String, String> results;
  /// When the order was made (server mode); null for the sample data.
  final DateTime? createdAt;
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
    this.packageCategory,
    this.createdAt,
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
    packageCategory: packageCategory,
    createdAt: createdAt,
  );
}

const kPatientsSeed = <Patient>[
  Patient(
    id: 'seed-1',
    name: 'Ali Ahmed',
    age: '32Y',
    gender: 'Male',
    phone: '+964 770 412 3356',
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
    phone: '+964 750 218 9047',
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
    phone: '+964 771 635 2280',
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
    phone: '+964 780 954 1173',
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

/// External lab referral (design `lw`).
class Referral {
  final String id, patient, test, lab, status, eta, tracking;
  final int step;
  /// 'Male' | 'Female' | '' and age in years ('' when unknown).
  final String gender, age;
  const Referral({
    required this.id,
    required this.patient,
    required this.test,
    required this.lab,
    required this.status,
    required this.eta,
    required this.tracking,
    required this.step,
    this.gender = '',
    this.age = '',
  });
}

/// Destination lab card (design `hw`).
class PartnerLab {
  final String name, city, rating, dist, price;
  /// Server id when the lab is registered on LabGo ('' otherwise).
  final String id;
  const PartnerLab(this.name, this.city, this.rating, this.dist, this.price, {this.id = ''});
}

/// Sample received from another lab (design `Df`).
class ReceivedSample {
  final String id, code, patient, test, lab, status;
  /// Server mode: on_the_way | received | completed, and the details.
  final String state, gender, age;
  final List<String> tests;
  final Map<String, String> values;
  final int? price;
  final DateTime? sentAt;
  const ReceivedSample({
    required this.id,
    required this.code,
    required this.patient,
    required this.test,
    required this.lab,
    required this.status,
    this.state = 'received',
    this.gender = '',
    this.age = '',
    this.tests = const [],
    this.values = const {},
    this.price,
    this.sentAt,
  });
}

const kReferralsSeed = <Referral>[
  Referral(
    id: 'ref-1',
    patient: 'Sara Ali',
    test: 'Vitamin D',
    lab: 'Al-Noor Lab',
    status: 'In Transit',
    eta: 'Tomorrow 2pm',
    tracking: 'LG-2026-124',
    step: 1,
  ),
  Referral(
    id: 'ref-2',
    patient: 'Omar Yousef',
    test: 'Hormone',
    lab: 'Al-Noor Lab',
    status: 'Sent',
    eta: 'Tomorrow 2pm',
    tracking: 'LG-2026-123',
    step: 0,
  ),
];

const kPartnerLabsSeed = <PartnerLab>[
  PartnerLab('Al-Noor Lab', 'Mosul', '4.9', '2.1 km', 'From 20,000 IQD'),
  PartnerLab('Al-Salam Lab', 'Erbil', '4.8', '68 km', 'From 25,000 IQD'),
  PartnerLab('City Lab', 'Baghdad', '4.7', '310 km', 'From 18,000 IQD'),
];

/// A staff account managed under Users & Roles (design `aH`).
class ManagedUser {
  final String id, name, phone, email, password, roleId;
  final bool active;
  const ManagedUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.password = '',
    required this.roleId,
    required this.active,
  });
  ManagedUser copyWith({bool? active}) => ManagedUser(
    id: id,
    name: name,
    phone: phone,
    email: email,
    password: password,
    roleId: roleId,
    active: active ?? this.active,
  );
}

/// A role with permissions (design `gH`).
class LabRole {
  final String id, name, description;
  final int color;
  final List<String> permissions;
  final bool isDefault;
  const LabRole({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.permissions,
    this.isDefault = false,
  });
  LabRole copyWith({List<String>? permissions}) => LabRole(
    id: id,
    name: name,
    description: description,
    color: color,
    permissions: permissions ?? this.permissions,
    isDefault: isDefault,
  );
}

/// Waste transfer request (design `zm`).
class WasteTransfer {
  final String id, date, type, status, driver, notes;
  final double weight;
  /// Request number printed on the pickup report.
  final int requestNo;
  const WasteTransfer({
    required this.id,
    required this.date,
    required this.type,
    required this.weight,
    this.status = 'Pending',
    this.driver = '',
    this.notes = '',
    this.requestNo = 0,
  });
}

/// Product / lab-for-sale order created from Settings (design `Fr`).
class ProductOrder {
  final String id, productName, code, address, phone, createdAt;
  final int price, quantity, total;
  const ProductOrder({
    required this.id,
    required this.productName,
    required this.code,
    required this.price,
    required this.quantity,
    required this.total,
    required this.address,
    required this.phone,
    required this.createdAt,
  });
}

const kPermissions = <(String, String, String, String)>[
  ('patients', 'Manage Patients', 'إدارة المرضى', 'بەڕێوەبردنی نەخۆش'),
  ('results', 'Enter Results', 'إدخال النتائج', 'تۆمارکردنی ئەنجام'),
  ('tests', 'Manage Tests', 'إدارة الفحوصات', 'بەڕێوەبردنی پشکنین'),
  ('packages', 'Manage Packages', 'إدارة الباقات', 'بەڕێوەبردنی پاکێج'),
  ('finance', 'Finance', 'المالية', 'دارایی'),
  ('waste', 'Manage Waste', 'إدارة النفايات', 'بەڕێوەبردنی پاشماوە'),
  ('store', 'Store', 'المتجر', 'فرۆشگا'),
  ('users', 'Manage Users', 'إدارة المستخدمين', 'بەڕێوەبردنی بەکارهێنەر'),
  ('settings', 'Settings', 'الإعدادات', 'ڕێکخستنەکان'),
];

/// Translated names / descriptions of the built-in roles (design `K6`).
const kRoleText =
    <String, ((String, String, String), (String, String, String))>{
      'role-admin': (
        (
          'Lab Manager (Admin)',
          'مدير المختبر (Admin)',
          'بەڕێوەبەری تاقیگە (Admin)',
        ),
        ('All permissions', 'كل الصلاحيات', 'هەموو مۆڵەتەکان'),
      ),
      'role-technician': (
        ('Lab Technician', 'فني مختبر (Technician)', 'تەکنیکی تاقیگە'),
        ('Results + Samples', 'النتائج + العينات', 'ئەنجام + نمونە'),
      ),
      'role-receptionist': (
        ('Receptionist', 'موظف استقبال (Receptionist)', 'پێشوازی'),
        (
          'Patient registration + Reports',
          'تسجيل المرضى + التقارير',
          'تۆمارکردنی نەخۆش + ڕاپۆرت',
        ),
      ),
      'role-accountant': (
        ('Accountant', 'محاسب (Accountant)', 'ژمێریار'),
        ('Finance only', 'المالية فقط', 'تەنها دارایی'),
      ),
      'role-guest': (
        ('Guest', 'ضيف (Guest)', 'میوان'),
        ('View only', 'عرض فقط', 'تەنها بینین'),
      ),
    };

const kRolesSeed = <LabRole>[
  LabRole(
    id: 'role-admin',
    name: 'مدير المختبر (Admin)',
    description: 'كل الصلاحيات',
    color: 0xFFFF5A00,
    permissions: [
      'patients',
      'results',
      'tests',
      'packages',
      'finance',
      'waste',
      'store',
      'users',
      'settings',
    ],
    isDefault: true,
  ),
  LabRole(
    id: 'role-technician',
    name: 'فني مختبر (Technician)',
    description: 'النتائج + العينات',
    color: 0xFF007AFF,
    permissions: ['results', 'patients'],
    isDefault: true,
  ),
  LabRole(
    id: 'role-receptionist',
    name: 'موظف استقبال (Receptionist)',
    description: 'تسجيل المرضى + التقارير',
    color: 0xFF34C759,
    permissions: ['patients', 'results'],
    isDefault: true,
  ),
  LabRole(
    id: 'role-accountant',
    name: 'محاسب (Accountant)',
    description: 'المالية فقط',
    color: 0xFFAF52DE,
    permissions: ['finance'],
    isDefault: true,
  ),
  LabRole(
    id: 'role-guest',
    name: 'ضيف (Guest)',
    description: 'عرض فقط',
    color: 0xFF8A8A8E,
    permissions: [],
    isDefault: true,
  ),
];

const kUsersSeed = <ManagedUser>[
  ManagedUser(
    id: 'user-admin',
    name: 'Admin — LabGo',
    phone: '+964 770 412 3356',
    email: 'admin@labgo.iq',
    roleId: 'role-admin',
    active: true,
  ),
  ManagedUser(
    id: 'user-manager',
    name: 'Dr. Ahmed',
    phone: '+964 750 218 9047',
    email: 'ahmed@labgo.iq',
    roleId: 'role-admin',
    active: true,
  ),
  ManagedUser(
    id: 'user-technician',
    name: 'Ali Hassan',
    phone: '+964 771 635 2280',
    email: 'ali@labgo.iq',
    roleId: 'role-technician',
    active: true,
  ),
  ManagedUser(
    id: 'user-receptionist',
    name: 'Sara Ali',
    phone: '+964 780 954 1173',
    email: 'sara@labgo.iq',
    roleId: 'role-receptionist',
    active: true,
  ),
];

const kWasteSeed = <WasteTransfer>[
  WasteTransfer(id: 'tr-2', date: '2026-11-12', type: 'Sharps', weight: 1.2, requestNo: 1002),
  WasteTransfer(id: 'tr-1', date: '2026-11-05', type: 'Biohazard', weight: 2.4, notes: 'Blood bags', requestNo: 1001),
];

/// A licence holder printed in the report header ("Dr. Ahmed Hamdoon · Bacteriologist").
class LicenseHolder {
  String title, name, specialty;
  LicenseHolder(this.title, this.name, this.specialty);

  String get line => [[title, name].where((x) => x.trim().isNotEmpty).join(' '), specialty]
      .where((x) => x.trim().isNotEmpty)
      .join(' · ');
}

/// A lab supplies purchase order (Settings → Create Order), printed as a PDF.
class SupplyItem {
  String name, qty, unit;
  SupplyItem([this.name = '', this.qty = '', this.unit = '']);
  Map<String, String> toJson() => {'name': name, 'qty': qty, 'unit': unit};
  static SupplyItem fromJson(Map<String, dynamic> j) => SupplyItem('${j['name'] ?? ''}', '${j['qty'] ?? ''}', '${j['unit'] ?? ''}');
}

class SupplyOrder {
  final int no;
  final String date, supplier, supplierPhone, neededBy, notes;
  final List<SupplyItem> items;
  const SupplyOrder({required this.no, required this.date, required this.supplier, required this.supplierPhone, required this.neededBy, required this.notes, required this.items});
  Map<String, dynamic> toJson() => {'no': no, 'date': date, 'supplier': supplier, 'supplierPhone': supplierPhone, 'neededBy': neededBy, 'notes': notes, 'items': [for (final i in items) i.toJson()]};
  static SupplyOrder fromJson(Map<String, dynamic> j) => SupplyOrder(
        no: (j['no'] as num?)?.toInt() ?? 0,
        date: '${j['date'] ?? ''}',
        supplier: '${j['supplier'] ?? ''}',
        supplierPhone: '${j['supplierPhone'] ?? ''}',
        neededBy: '${j['neededBy'] ?? ''}',
        notes: '${j['notes'] ?? ''}',
        items: [for (final i in (j['items'] as List? ?? const [])) SupplyItem.fromJson(Map<String, dynamic>.from(i as Map))],
      );
}

/// A listing in the labs' marketplace: product, auction (device or lab) or lab for sale.
class MarketItem {
  final String id, kind, title, description, category, condition, code, unit, location, area, equipment;
  final int price, stock, currentBid, bids, durationDays;
  final List<String> images;
  final List<Uint8List> localImages;
  final String approvalStatus, rejectReason, status, labName, topBidder;
  final bool mine, youLead, won;
  final DateTime? endsAt, startedAt, createdAt;

  const MarketItem({
    this.id = '',
    required this.kind,
    required this.title,
    this.description = '',
    this.category = '',
    this.condition = '',
    this.code = '',
    this.unit = '',
    this.location = '',
    this.area = '',
    this.equipment = '',
    required this.price,
    this.stock = 0,
    this.currentBid = 0,
    this.bids = 0,
    this.durationDays = 3,
    this.images = const [],
    this.localImages = const [],
    this.approvalStatus = 'pending',
    this.rejectReason = '',
    this.status = 'active',
    this.labName = '',
    this.topBidder = '',
    this.mine = false,
    this.youLead = false,
    this.won = false,
    this.endsAt,
    this.startedAt,
    this.createdAt,
  });

  bool get isAuction => kind == 'auction' || kind == 'lab_auction';
  bool get isLab => kind == 'lab_sale' || kind == 'lab_auction';
  bool get approved => approvalStatus == 'approved';

  static MarketItem fromJson(Map<String, dynamic> j) {
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    DateTime? d(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
    return MarketItem(
      id: '${j['id'] ?? j['_id'] ?? ''}',
      kind: '${j['kind'] ?? 'product'}',
      title: '${j['title'] ?? ''}',
      description: '${j['description'] ?? ''}',
      category: '${j['category'] ?? ''}',
      condition: '${j['condition'] ?? ''}',
      code: '${j['code'] ?? ''}',
      unit: '${j['unit'] ?? ''}',
      location: '${j['location'] ?? ''}',
      area: '${j['area'] ?? ''}',
      equipment: '${j['equipment'] ?? ''}',
      price: n(j['price']),
      stock: n(j['stock']),
      currentBid: n(j['currentBid']),
      bids: j['bids'] is List ? (j['bids'] as List).length : n(j['bids']),
      images: [for (final u in (j['images'] as List? ?? const [])) '$u'],
      approvalStatus: '${j['approvalStatus'] ?? 'pending'}',
      rejectReason: '${j['rejectReason'] ?? ''}',
      status: '${j['status'] ?? 'active'}',
      labName: '${(j['lab'] as Map?)?['name'] ?? ''}',
      topBidder: '${j['topBidder'] ?? ''}',
      mine: j['mine'] == true,
      youLead: j['youLead'] == true,
      won: j['won'] == true,
      endsAt: d(j['endsAt']),
      startedAt: d(j['startedAt']),
      createdAt: d(j['createdAt']),
    );
  }

  Map<String, String> toFields() => {
        'kind': kind,
        'title': title,
        'description': description,
        'category': category,
        'condition': condition,
        'code': code,
        'price': '$price',
        'stock': '$stock',
        'unit': unit,
        'location': location,
        'area': area,
        'equipment': equipment,
        'days': '$durationDays',
      };

  MarketItem copyWithLocal(List<Uint8List> imgs) => MarketItem(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        kind: kind, title: title, description: description, category: category, condition: condition, code: code,
        unit: unit, location: location, area: area, equipment: equipment, price: price, stock: stock,
        currentBid: price, durationDays: durationDays, localImages: imgs, mine: true, createdAt: DateTime.now(),
      );
}
