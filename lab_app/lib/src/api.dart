import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Connection to the LabGo server (the same data as the web dashboard).
///
/// The server address comes from the build:
///   flutter run --dart-define=API_BASE=https://your-server.com
/// Without it the app runs in demo mode on the built-in sample data.
class LabApi {
  LabApi._();
  static final LabApi instance = LabApi._();

  static const String base = String.fromEnvironment('API_BASE');
  static bool get enabled => base.isNotEmpty;

  static const _tokenKey = 'labgo_token';
  String? _token;

  bool get signedIn => _token != null;

  Uri _uri(String path) => Uri.parse('${base.replaceAll(RegExp(r'/+$'), '')}$path');

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
    } catch (_) {
      _token = null;
    }
  }

  Future<void> _saveToken(String? token) async {
    _token = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token == null) {
        await prefs.remove(_tokenKey);
      } else {
        await prefs.setString(_tokenKey, token);
      }
    } catch (_) {/* stays signed in for this run only */}
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Object? body,
  ]) async {
    final req = http.Request(method, _uri(path))..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final streamed = await req.send().timeout(const Duration(seconds: 20));
    final res = await http.Response.fromStream(streamed);
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiError(res.statusCode, 'Unexpected server response');
    }
    if (res.statusCode == 401) await _saveToken(null);
    if (res.statusCode >= 400 || json['success'] == false) {
      throw ApiError(res.statusCode, (json['message'] ?? 'Request failed').toString());
    }
    return json;
  }

  /// Signs in with a phone number or email and password (lab owner or staff).
  Future<void> login(String id, String password) async {
    final json = await _send('POST', '/api/auth/login', {
      'loginInput': normalizePhone(id),
      'password': password,
    });
    final role = (json['user'] as Map?)?['role'];
    if (role != 'lab') throw ApiError(403, 'This account is not a lab account');
    await _saveToken(json['token'] as String?);
  }

  Future<void> logout() => _saveToken(null);

  Future<Bootstrap> bootstrap() async {
    final json = await _send('GET', '/lab/api/app/bootstrap');
    return Bootstrap.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<List<Patient>> patients() async {
    final json = await _send('GET', '/lab/api/app/patients');
    return ((json['data'] as Map)['patients'] as List)
        .map((e) => patientFromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Registers a patient at the lab; returns the new order id.
  Future<String> addPatient(Map<String, dynamic> body) async {
    final json = await _send('POST', '/lab/api/walk-in-orders', body);
    return (json['data'] as Map)['orderId'].toString();
  }

  /// Saves result values as a draft (test name -> value).
  Future<void> saveResults(String orderId, Map<String, String> values) async {
    await _send('PUT', '/lab/api/orders/$orderId/results', {
      'values': [
        for (final e in values.entries) {'testName': e.key, 'value': e.value},
      ],
    });
  }

  /// 10-digit Iraqi mobiles typed without the leading 0 get it back.
  static String normalizePhone(String v) {
    final t = v.trim();
    if (t.contains('@')) return t;
    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && digits.startsWith('7')) return '0$digits';
    return t;
  }
}

class ApiError implements Exception {
  final int status;
  final String message;
  ApiError(this.status, this.message);
  @override
  String toString() => message;
}

class Bootstrap {
  final Map<String, dynamic> user, lab;
  final List<CatalogTest> catalog;
  final Map<String, String> testIds; // test name -> server id
  final List<LabPackage> packages;
  final List<Patient> patients;
  Bootstrap(this.user, this.lab, this.catalog, this.testIds, this.packages, this.patients);

  factory Bootstrap.fromJson(Map<String, dynamic> j) {
    final ids = <String, String>{};
    final catalog = <CatalogTest>[];
    for (final raw in (j['catalog'] as List)) {
      final c = raw as Map<String, dynamic>;
      ids[c['name'] as String] = c['id'] as String;
      catalog.add(
        CatalogTest(
          name: c['name'] as String,
          price: (c['price'] as num).toInt(),
          priceB2B: (c['priceB2B'] as num).toInt(),
          category: (c['category'] ?? 'General') as String,
          on: c['on'] == true,
          units: (c['units'] ?? '') as String,
          normalText: (c['normalText'] ?? '') as String,
          ranges: [
            for (final r in (c['ranges'] as List))
              RangeRow(
                '${r['ageFrom']}',
                '${r['ageTo']}',
                '${r['ageUnit']}',
                '${r['gender']}',
                '${r['min']}',
                '${r['max']}',
              ),
          ],
        ),
      );
    }
    final packages = [
      for (final raw in (j['packages'] as List))
        () {
          final p = raw as Map<String, dynamic>;
          return LabPackage(
            id: p['id'] as String,
            code: (p['code'] ?? '') as String,
            name: p['name'] as String,
            category: (p['category'] ?? 'General') as String,
            aliases: [for (final a in (p['aliases'] as List)) '$a'],
            tests: [for (final t in (p['tests'] as List)) '$t'],
            price: (p['price'] as num).toInt(),
            priceB2B: (p['priceB2B'] as num).toInt(),
            active: p['active'] == true,
          );
        }(),
    ];
    return Bootstrap(
      j['user'] as Map<String, dynamic>,
      j['lab'] as Map<String, dynamic>,
      catalog,
      ids,
      packages,
      [
        for (final p in (j['patients'] as List))
          patientFromJson(p as Map<String, dynamic>),
      ],
    );
  }
}

Patient patientFromJson(Map<String, dynamic> j) => Patient(
  id: j['id'] as String,
  name: (j['name'] ?? '') as String,
  age: (j['age'] ?? '—') as String,
  gender: (j['gender'] ?? 'Male') as String,
  phone: (j['phone'] ?? '') as String,
  tests: [for (final t in (j['tests'] as List)) '$t'],
  sample: (j['sample'] ?? 'Blood') as String,
  urgency: (j['urgency'] ?? 'Normal') as String,
  notes: (j['notes'] ?? '') as String,
  status: (j['status'] ?? 'Pending') as String,
  time: (j['time'] ?? '') as String,
  price: ((j['price'] ?? 0) as num).toInt(),
  doctor: (j['doctor'] ?? '') as String,
  mode: (j['mode'] ?? 'B2C') as String,
  company: j['company'] as String?,
  results: {
    for (final e in ((j['results'] ?? {}) as Map).entries) '${e.key}': '${e.value}',
  },
  permanent: (j['permanent'] ?? '') as String,
  createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}')?.toLocal(),
);
