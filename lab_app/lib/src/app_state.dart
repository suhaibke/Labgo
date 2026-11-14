import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'catalog_data.dart';
import 'models.dart';
import 'report_pdf.dart';
import 'results_logic.dart';
import 'screens/store_screen.dart';
import 'strings_data.dart';
import 'theme.dart';

/// Single app-wide state, mirroring the design's root component.
/// Runs on the LabGo server when the app is built with API_BASE (see api.dart),
/// otherwise on local sample data (demo mode).
class AppState extends ChangeNotifier {
  // ---- appearance -------------------------------------------------------
  /// Arabic first; the choice is remembered on the device.
  String lang = 'ar';
  bool darkMode = false;
  String accentKey = 'orange';

  bool get rtl => lang != 'en';

  Palette get palette {
    final a = kAccents.firstWhere(
      (e) => e.key == accentKey,
      orElse: () => kAccents.first,
    );
    return darkMode ? Palette.dark(a.darkHex) : Palette.light(a.hex);
  }

  /// Picks the right translation for inline strings: tr('Ar', 'Ku', 'En').
  String tr(String ar, String ku, String en) => lang == 'ar'
      ? ar
      : lang == 'ku'
      ? ku
      : en;

  String d(String key) => kDStrings[lang]?[key] ?? kDStrings['en']?[key] ?? key;
  String w(String key) => kWStrings[lang]?[key] ?? kWStrings['en']?[key] ?? key;
  String p(String key) => kPStrings[lang]?[key] ?? kPStrings['en']?[key] ?? key;
  String t(String key) => kTStrings[lang]?[key] ?? kTStrings['en']?[key] ?? key;

  /// Pick from an (en, ar, ku) triple.
  String pick((String, String, String) v) => lang == 'ar'
      ? v.$2
      : lang == 'ku'
      ? v.$3
      : v.$1;

  String get langBadge => lang == 'en'
      ? 'EN'
      : lang == 'ar'
      ? 'AR'
      : 'KU';

  void toggleTheme() {
    darkMode = !darkMode;
    notifyListeners();
  }

  void cycleLanguage() {
    const order = ['en', 'ar', 'ku'];
    lang = order[(order.indexOf(lang) + 1) % 3];
    SharedPreferences.getInstance().then((p) => p.setString('lab.lang', lang)).catchError((Object _) => false);
    final names = {
      'en': kDStrings['en']!['langEnglish']!,
      'ar': kDStrings['ar']!['langArabic']!,
      'ku': kDStrings['ku']!['langKurdish']!,
    };
    toast('${kDStrings[lang]!['langSwitched']} • ${names[lang]}');
  }

  // ---- toast ------------------------------------------------------------
  String? toastText;
  Timer? _toastTimer;

  void toast(String text) {
    toastText = text;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      toastText = null;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Green banner shown above auth forms (design `a2`).
  String? authBanner;
  void setAuthBanner(String? text) {
    authBanner = text;
    notifyListeners();
  }

  // ---- splash -------------------------------------------------------------
  bool splashVisible = true;
  bool splashFading = false;

  // ---- server connection -------------------------------------------------
  /// Server ids of the lab's tests (by name), used when adding a patient.
  Map<String, String> testIds = {};
  bool loading = false;

  /// On start: a saved session opens the app straight away.
  Future<void> restoreSession() async {
    if (!LabApi.enabled) return;
    await LabApi.instance.restore();
    if (!LabApi.instance.signedIn) return;
    try {
      await _loadFromServer();
      auth = 'app';
      tab = 'home';
      notifyListeners();
    } catch (_) {
      await LabApi.instance.logout();
    }
  }

  /// Login button: demo mode just opens the app.
  Future<void> signIn(String id, String password, {void Function(String)? onError}) async {
    if (!LabApi.enabled) {
      enterApp();
      return;
    }
    if (loading) return;
    loading = true;
    notifyListeners();
    try {
      await LabApi.instance.login(id, password);
      await _loadFromServer();
      enterApp();
    } catch (e) {
      onError?.call(e.toString());
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Changes made on the web dashboard (tests and ranges, packages, roles,
  /// lab details, patients…) reach the app when it comes back to the
  /// foreground and every two minutes. Nothing typed here is lost: an open
  /// result entry or an unsaved lab edit keeps its values.
  DateTime _lastSync = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _syncTimer;

  Future<void> syncFromServer({bool force = false}) async {
    if (!LabApi.enabled || !LabApi.instance.signedIn || auth != 'app') return;
    if (!force && DateTime.now().difference(_lastSync) < const Duration(seconds: 20)) return;
    if (_labKey != _labSaved) return; // a lab edit is still being saved
    _lastSync = DateTime.now();
    try {
      final keep = selectedPatient;
      await _loadFromServer();
      if (keep != null) {
        for (final p in patients) {
          if (p.id == keep.id) selectedPatient = p;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadFromServer() async {
    _syncTimer ??= Timer.periodic(const Duration(minutes: 2), (_) => syncFromServer());
    _lastSync = DateTime.now();
    final b = await LabApi.instance.bootstrap();
    kCatalog
      ..clear()
      ..addAll(b.catalog);
    kPackages
      ..clear()
      ..addAll(b.packages);
    testIds = b.testIds;
    kCatalogAliases
      ..clear()
      ..addAll(b.aliases);
    patients = b.patients;
    final userName = (b.user['name'] ?? '') as String;
    if (userName.isNotEmpty) {
      doctorName = userName;
      profileInitial = userName.trim()[0].toUpperCase();
    }
    userPhone = (b.user['phone'] ?? userPhone) as String;
    labName = (b.lab['name'] ?? labName) as String;
    labDisplayName = labName;
    labPhone = (b.lab['phone'] ?? labPhone) as String;
    labAddress = (b.lab['address'] ?? labAddress) as String;
    userAddress = labAddress;
    licenseOwners = (b.lab['licenseOwners'] ?? '') as String;
    labEmail = '${b.lab['email'] ?? ''}';
    labWebsite = '${b.lab['website'] ?? ''}';
    labDescription = '${b.lab['description'] ?? ''}';
    platformFooter = b.lab['platformFooter'] != false;
    licenseHolders = [
      for (final h in (b.lab['licenseHolders'] as List? ?? const []))
        LicenseHolder('${h['title'] ?? ''}', '${h['name'] ?? ''}', '${h['specialty'] ?? ''}'),
    ];
    _labSaved = _labKey;
    // The logo and photo stored on the server (used in the app and the report PDF).
    LabApi.instance.fetchBytes('${b.lab['logo'] ?? ''}').then((v) {
      if (v != null) {
        labLogo = Uint8List.fromList(v);
        notifyListeners();
      }
    });
    LabApi.instance.fetchBytes('${b.user['photo'] ?? ''}').then((v) {
      if (v != null) {
        userPhoto = Uint8List.fromList(v);
        notifyListeners();
      }
    });
    permissions = [for (final p in (b.user['permissions'] as List? ?? const [])) '$p'];
    isOwner = b.user['isOwner'] == true;
    if (!isOwner && !permissions.contains('users')) users = [];
    referrals = [];
    partnerLabs = [];
    wasteTransfers = [];
    await Future.wait([_loadStaff(), _loadWaste(), loadFinance(), _loadTransfers(), _loadIncoming(), loadNotifications()]);
    _notifTimer ??= Timer.periodic(const Duration(seconds: 60), (_) => loadNotifications());
  }

  // ---- settings sections from the server --------------------------------
  List<String> permissions = [];
  bool isOwner = false;
  bool can(String p) => !LabApi.enabled || isOwner || permissions.contains(p);
  /// Finance card data (null = demo numbers).
  Map<String, dynamic>? _serverFinance;

  /// Expenses recorded on this device when not connected to the server.
  List<Map<String, dynamic>> localExpenses = [];

  /// Finance card data: the server's numbers, or worked out from this
  /// device's patients and expenses — never sample figures.
  Map<String, dynamic> get finance => _serverFinance ?? _localFinance();

  Map<String, dynamic> _localFinance() {
    num sum(Iterable<Patient> list) => list.fold<num>(0, (a, p) => a + p.price);
    final unpaid = patients.where((p) => p.status == 'Payment Pending');
    final paid = patients.where((p) => p.status != 'Payment Pending');
    final income = sum(paid);
    final byCategory = <String, num>{};
    for (final e in localExpenses) {
      byCategory['${e['category']}'] = (byCategory['${e['category']}'] ?? 0) + (e['amount'] as num);
    }
    final expenses = byCategory.values.fold<num>(0, (a, b) => a + b);
    // Six bars = the last six months; patients without a date count this month.
    final now = DateTime.now();
    final inc = List<double>.filled(6, 0), exp = List<double>.filled(6, 0);
    int slot(DateTime? d) {
      if (d == null) return 5;
      final m = (now.year - d.year) * 12 + now.month - d.month;
      return m < 0 || m > 5 ? -1 : 5 - m;
    }
    for (final p in paid) {
      final i = slot(p.createdAt);
      if (i >= 0) inc[i] += p.price;
    }
    for (final e in localExpenses) {
      final i = slot(DateTime.tryParse('${e['date']}'));
      if (i >= 0) exp[i] += (e['amount'] as num).toDouble();
    }
    return {
      'totals': {'income': income, 'expenses': expenses, 'profit': income - expenses, 'debts': sum(unpaid)},
      'byCategory': byCategory,
      'expenses': localExpenses,
      'debts': [for (final p in unpaid) {'name': p.name, 'amount': p.price}],
      'bars': {'income': inc, 'expenses': exp},
      'invoices': [
        for (final p in patients.take(6)) {'code': p.permanent.isEmpty ? p.id : p.permanent, 'name': p.name, 'amount': p.price, 'paid': p.status != 'Payment Pending'},
      ],
    };
  }

  Future<void> addExpense(String category, num amount, String note) async {
    if (amount <= 0) {
      toast(tr('اكتب المبلغ', 'بڕ بنووسە', 'Enter the amount'));
      return;
    }
    final e = {'category': category, 'amount': amount, 'note': note, 'date': DateTime.now().toIso8601String()};
    if (LabApi.enabled) {
      try {
        await LabApi.instance.addExpense(e);
        await loadFinance();
      } catch (err) {
        _serverError(err);
        return;
      }
    } else {
      localExpenses = [e, ...localExpenses];
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lab.expenses', jsonEncode(localExpenses));
      } catch (_) {}
      notifyListeners();
    }
    toast(tr('تمت إضافة المصروف ✓', 'خەرجی زیادکرا ✓', 'Expense added ✓'));
  }
  String _labSaved = '';
  Timer? _labTimer, _rolesTimer;

  static String _roleId(String key) => key.startsWith('c-') ? key : 'role-$key';
  static String _roleKey(String id) => id.startsWith('role-') ? id.substring(5) : id;
  static int _color(String? hex) {
    final h = (hex ?? '').replaceAll('#', '');
    return h.length == 6 ? int.parse('FF$h', radix: 16) : 0xFF8E8E93;
  }
  static String _hex(int c) => '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _applyStaff(Map<String, dynamic> data) {
    if (data['roles'] is List) {
      roles = [
        for (final r in data['roles'] as List)
          LabRole(
            id: _roleId('${r['key']}'),
            name: '${r['name'] ?? ''}',
            description: '',
            color: _color(r['color'] as String?),
            permissions: [for (final p in (r['permissions'] as List)) '$p'],
            isDefault: r['isDefault'] == true,
          ),
      ];
    }
    if (data['staff'] is List) {
      users = [
        for (final u in data['staff'] as List)
          ManagedUser(
            id: '${u['_id']}',
            name: '${u['name'] ?? ''}',
            phone: '${u['phone'] ?? ''}',
            email: '${u['email'] ?? ''}',
            roleId: _roleId('${u['roleKey']}'),
            active: u['active'] != false,
          ),
      ];
    }
  }

  Future<void> _loadStaff() async {
    if (!can('users')) return;
    try {
      _applyStaff(await LabApi.instance.staff());
    } catch (_) {}
  }

  Future<void> _loadWaste() async {
    if (!can('waste')) return;
    try {
      final data = await LabApi.instance.waste();
      String cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);
      wasteTransfers = [
        for (final w in (data['items'] as List? ?? const []))
          WasteTransfer(
            id: '${w['_id']}',
            date: '${w['pickupDate'] ?? ''}'.split('T').first,
            type: cap('${w['type']}'),
            weight: ((w['weightKg'] ?? 0) as num).toDouble(),
            status: w['status'] == 'collected' ? 'Completed' : 'Pending',
            notes: '${w['notes'] ?? ''}',
            requestNo: ((w['requestNo'] ?? 0) as num).toInt(),
          ),
      ];
    } catch (_) {}
  }

  Future<void> loadFinance() async {
    if (!can('finance')) return;
    try {
      _serverFinance = await LabApi.instance.finance();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadTransfers() async {
    if (!can('patients') && !can('results')) return;
    try {
      final data = await LabApi.instance.transfers();
      referrals = [
        for (final r in (data['referrals'] as List? ?? const []))
          Referral(
            id: '${r['id']}',
            patient: '${r['patient']}',
            test: '${r['test']}',
            lab: '${r['lab']}',
            status: '${r['status']}',
            eta: '${r['eta']}',
            tracking: '${r['tracking']}',
            step: ((r['step'] ?? 0) as num).toInt(),
            gender: r['gender'] == 'female' ? 'Female' : r['gender'] == 'male' ? 'Male' : '',
            age: r['age'] == null ? '' : '${r['age']}',
          ),
      ];
      // Labs registered on LabGo first (price from their B2B prices), then
      // other labs this lab sent to before.
      final names = [for (final l in (data['labs'] as List? ?? const [])) '$l'];
      List<dynamic> dir = const [];
      try {
        dir = await LabApi.instance.labDirectory();
      } catch (_) {}
      final registered = [
        for (final l in dir)
          PartnerLab(
            '${l['name']}',
            '${l['city'] ?? ''}'.isEmpty ? '—' : '${l['city']}',
            ((l['rating'] ?? 0) as num) > 0 ? (l['rating'] as num).toStringAsFixed(1) : '—',
            'LabGo',
            '',
            id: '${l['id']}',
          ),
      ];
      partnerLabs = [
        ...registered,
        for (final n in names)
          if (!registered.any((l) => l.name.toLowerCase() == n.toLowerCase())) PartnerLab(n, '—', '—', '—', ''),
      ];
      notifyListeners();
      _quoteLabs();
    } catch (_) {}
  }

  // ---- B2B price of the receiving lab --------------------------------------
  /// Lab id -> price for the chosen test (null = that lab has no price for it).
  Map<String, int?> labQuotes = {};
  String _quotedTest = '';
  String refPrice = '';
  bool refPriceEdited = false;
  Timer? _notifTimer;

  static String money(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  String get currency => tr('د.ع', 'د.ع', 'IQD');

  PartnerLab? get refLabObj {
    for (final l in partnerLabs) {
      if (l.name == refLab) return l;
    }
    return null;
  }

  int? get refQuote {
    final l = refLabObj;
    return l == null || l.id.isEmpty ? null : labQuotes[l.id];
  }

  /// Price shown on a lab card.
  String labPriceText(PartnerLab l) {
    if (l.id.isEmpty) return l.price;
    if (!labQuotes.containsKey(l.id)) return '…';
    final v = labQuotes[l.id];
    return v == null ? tr('لا يوجد سعر', 'نرخ نییە', 'No price') : '${money(v)} $currency';
  }

  void _syncRefPrice() {
    if (refPriceEdited) return;
    final q = refQuote;
    refPrice = q == null ? '' : money(q);
  }

  Future<void> _quoteLabs() async {
    if (!LabApi.enabled || refTests.isEmpty) return;
    final test = refTests.join(',');
    _quotedTest = test;
    final labs = partnerLabs.where((l) => l.id.isNotEmpty).take(15).toList();
    await Future.wait([
      for (final l in labs)
        LabApi.instance.labQuote(l.id, List.of(refTests)).then((q) {
          if (_quotedTest != test) return;
          labQuotes = {...labQuotes, l.id: (q['lines'] as List?)?.isNotEmpty == true ? (q['total'] as num).toInt() : null};
        }).catchError((Object _) {}),
    ]);
    if (_quotedTest == test) {
      _syncRefPrice();
      notifyListeners();
    }
  }

  void setRefPrice(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    refPrice = digits.isEmpty ? '' : money(int.parse(digits));
    refPriceEdited = true;
    notifyListeners();
  }

  // ---- samples other LabGo labs sent to this lab ---------------------------
  List<ReceivedSample> incomingAll = [];

  ReceivedSample _incomingFromJson(Map<String, dynamic> t) {
    final state = '${t['status']}';
    final tests = [for (final x in (t['tests'] as List? ?? const [])) '$x'];
    return ReceivedSample(
      id: '${t['id']}',
      code: '${t['code']}',
      patient: '${t['patient'] ?? ''}',
      test: tests.join(', '),
      lab: '${t['fromLab'] ?? ''}',
      status: state == 'completed'
          ? tr('مكتملة', 'تەواو', 'Completed')
          : state == 'received'
          ? tr('مستلمة', 'وەرگیرا', 'Received')
          : tr('في الطريق', 'لە ڕێگادا', 'On the way'),
      state: state,
      gender: '${t['gender'] ?? ''}',
      age: t['age'] == null ? '' : '${t['age']}',
      tests: tests,
      values: {for (final e in ((t['values'] ?? {}) as Map).entries) '${e.key}': '${e.value}'},
      price: (t['price'] as num?)?.toInt(),
      sentAt: DateTime.tryParse('${t['sentAt'] ?? ''}')?.toLocal(),
    );
  }

  Future<void> _loadIncoming() async {
    if (!can('patients') && !can('results')) return;
    try {
      final items = await LabApi.instance.incomingTransfers();
      incomingAll = [for (final t in items) _incomingFromJson(t as Map<String, dynamic>)];
      receivedSamples = incomingAll.where((x) => x.state != 'on_the_way').toList();
      if (foundSample != null) {
        for (final x in incomingAll) {
          if (x.id == foundSample!.id) foundSample = x;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Opens a received sample in the result-entry screen; approving it sends
  /// the result straight to the lab that sent it.
  void openIncoming(ReceivedSample r) {
    if (r.state == 'on_the_way') {
      toast(tr('استلم العينة أولاً', 'سەرەتا نموونەکە وەربگرە', 'Receive the sample first'));
      return;
    }
    openPatient(Patient(
      id: 'tr:${r.id}',
      name: r.patient,
      age: r.age.isEmpty ? '—' : r.age,
      gender: r.gender == 'female' ? 'Female' : 'Male',
      phone: '',
      tests: r.tests,
      sample: 'Blood',
      urgency: 'Normal',
      notes: '',
      status: r.state == 'completed' ? 'Completed' : 'Pending',
      // Header: sample code • sending lab • date sent.
      time: r.lab,
      price: r.price ?? 0,
      doctor: '',
      mode: 'B2B',
      company: r.lab,
      results: r.values,
      permanent: r.code,
      createdAt: r.sentAt ?? DateTime.now(),
    ));
  }

  // ---- lab notifications (server) ------------------------------------------
  List<Map<String, dynamic>> serverNotifs = [];

  Future<void> loadNotifications() async {
    if (!LabApi.enabled) return;
    try {
      final data = await LabApi.instance.notifications();
      final before = serverNotifs.map((n) => n['id']).toSet();
      serverNotifs = [for (final n in (data['items'] as List? ?? const [])) Map<String, dynamic>.from(n as Map)];
      for (final n in serverNotifs) {
        if (n['isRead'] == true) readNotifications.add('${n['id']}');
      }
      // Something new arrived: alert, and refresh the lists it is about.
      final fresh = serverNotifs.where((n) => !before.contains(n['id']) && n['isRead'] != true);
      if (_notifsLoaded && fresh.isNotEmpty) {
        alertNotification();
        _loadTransfers();
        _loadIncoming();
        refreshPatients();
      }
      _notifsLoaded = true;
      notifyListeners();
    } catch (_) {}
  }

  String _ago(DateTime t) {
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 1) return tr('الآن', 'ئێستا', 'now');
    if (m < 60) return tr('قبل $m د', 'پێش $m خ', '${m}m ago');
    if (m < 1440) return tr('قبل ${m ~/ 60} س', 'پێش ${m ~/ 60} ک', '${m ~/ 60}h ago');
    return tr('قبل ${m ~/ 1440} يوم', 'پێش ${m ~/ 1440} ڕۆژ', '${m ~/ 1440}d ago');
  }

  bool _notifsLoaded = false;
  final AudioPlayer _chime = AudioPlayer();

  /// A new notification: vibration and a short sound.
  Future<void> alertNotification() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.vibrate();
    } catch (_) {}
    if (!notificationsOn) return;
    try {
      await _chime.stop();
      await _chime.play(AssetSource('sounds/notify.wav'));
    } catch (_) {}
  }

  /// Demo mode: sample notifications, plus one that arrives a little after
  /// signing in so the alert can be tried. (id, text, time, target)
  final List<(String, String, String, String)> _demoNotifs = [];
  Timer? _demoNotifTimer;

  List<(String, String, String, String)> get _demoList => [
        ..._demoNotifs,
        ('n1', w('n1'), w('n1Time'), 'results'),
        ('n2', w('n2'), w('n2Time'), 'results'),
        ('n3', w('n3'), w('n3Time'), 'waste'),
      ];

  void _scheduleDemoNotification() {
    if (LabApi.enabled || _demoNotifs.isNotEmpty) return;
    _demoNotifTimer?.cancel();
    _demoNotifTimer = Timer(const Duration(seconds: 20), () {
      if (auth != 'app') return;
      _demoNotifs.insert(0, (
        'n4',
        tr('عينة جديدة من مختبر النور — Zainab Kareem • Vitamin D', 'نموونەی نوێ لە تاقیگەی النور — Zainab Kareem • Vitamin D', 'New sample from Al-Noor Lab — Zainab Kareem • Vitamin D'),
        tr('الآن', 'ئێستا', 'now'),
        'receive',
      ));
      alertNotification();
      notifyListeners();
    });
  }

  /// Where a notification leads: results, receive (B2B), tracking (sent) or waste.
  String _notifTarget(String id) {
    if (!LabApi.enabled) {
      for (final n in _demoList) {
        if (n.$1 == id) return n.$4;
      }
      return 'results';
    }
    for (final n in serverNotifs) {
      if ('${n['id']}' != id) continue;
      final type = '${(n['data'] as Map?)?['type'] ?? ''}';
      if (type == 'transfer_incoming') return 'receive';
      if (type == 'transfer_received') return 'tracking';
      if (type.startsWith('market_') || type.startsWith('auction_')) return 'store';
      if (type == 'support_reply') return 'support';
      return 'results';
    }
    return 'results';
  }

  /// Tapping a notification: mark it read and open the screen it is about.
  void openNotification(String id) {
    final target = _notifTarget(id);
    markRead(id);
    notificationsOpen = false;
    selectedPatient = null;
    wastePage = false;
    switch (target) {
      case 'receive':
        tab = 'send';
        sendTab = 'receive';
        _loadIncoming();
      case 'tracking':
        tab = 'send';
        sendTab = 'send';
      case 'waste':
        tab = 'profile';
        wastePage = true;
      case 'store':
        storeOpen = true;
        loadMarket();
      case 'support':
        tab = 'profile';
        openSection = 'support';
        loadSupport();
      default:
        tab = 'results';
        refreshPatients();
    }
    notifyListeners();
  }

  /// (id, text, time) for the notifications sheet.
  List<(String, String, String)> get notificationItems => LabApi.enabled
      ? [
          for (final n in serverNotifs)
            (
              '${n['id']}',
              '${n['title']}\n${n['body']}',
              _ago(DateTime.tryParse('${n['createdAt']}')?.toLocal() ?? DateTime.now()),
            ),
        ]
      : [for (final n in _demoList) (n.$1, n.$2, n.$3)];

  void _serverError(Object e) {
    final code = e is ApiError ? e.code : null;
    const msgs = {
      'phoneTaken': ('هذا الرقم مسجل بحساب آخر', 'ئەم ژمارەیە هەژماری هەیە', 'This phone number already has an account'),
      'emailTaken': ('هذا البريد مسجل بحساب آخر', 'ئەم ئیمەیڵە هەژماری هەیە', 'This email already has an account'),
      'password': ('كلمة المرور 6 أحرف على الأقل', 'وشەی نهێنی لانیکەم ٦ پیت', 'Password must be at least 6 characters'),
      'phone': ('أدخل رقم هاتف صحيح', 'ژمارەیەکی دروست بنووسە', 'Enter a valid phone number'),
      'roleInUse': ('انقل الموظفين من هذا الدور أولاً', 'سەرەتا کارمەندانی ئەم ڕۆڵە بگوازەرەوە', 'Move the staff using this role first'),
      'duplicate': ('يوجد تحليل بنفس الاسم', 'پشکنینێک بەم ناوە هەیە', 'A test with this name already exists'),
      'packageTests': ('الباقة تحتاج تحليلين على الأقل', 'پاکێج لانیکەم دوو پشکنینی دەوێت', 'A package needs at least 2 tests'),
      'self': ('لا يمكنك تغيير دورك أو إيقاف حسابك', 'ناتوانیت ڕۆڵی خۆت بگۆڕیت', 'You cannot change your own role or disable yourself'),
    };
    final m = msgs[code];
    toast(m != null ? tr(m.$1, m.$2, m.$3) : e.toString());
  }

  String get _labKey => [labName, labPhone, labAddress, labEmail, labWebsite, labDescription, for (final h in licenseHolders) '${h.title}|${h.name}|${h.specialty}'].join('\u0001');

  /// Lab details are edited without a Save button: save shortly after typing stops.
  void _scheduleLabSave() {
    if (!LabApi.enabled || !LabApi.instance.signedIn) return;
    if (_labKey == _labSaved) return;
    _labTimer?.cancel();
    _labTimer = Timer(const Duration(milliseconds: 1200), () async {
      final sent = _labKey;
      try {
        await LabApi.instance.saveLab({
          'name': labName,
          'phone': labPhone,
          'address': labAddress,
          'email': labEmail,
          'website': labWebsite,
          'description': labDescription,
          'licenseHolders': [
            for (final h in licenseHolders)
              if (h.name.trim().isNotEmpty) {'title': h.title, 'name': h.name, 'specialty': h.specialty},
          ],
        });
        _labSaved = sent;
      } catch (e) {
        _serverError(e);
      }
    });
  }

  void _saveRolesSoon() {
    if (!LabApi.enabled) return;
    _rolesTimer?.cancel();
    _rolesTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        _applyStaff(await LabApi.instance.saveRoles([
          for (final r in roles)
            {
              'key': _roleKey(r.id),
              'name': r.isDefault ? '' : r.name,
              'color': _hex(r.color),
              'permissions': r.permissions,
            },
        ]));
        notifyListeners();
      } catch (e) {
        _serverError(e);
        await _loadStaff();
        notifyListeners();
      }
    });
  }

  /// Home card numbers for today / this week / this month:
  /// (patients, completed, pending, sent). Demo mode keeps the design's numbers.
  List<(int, int, int, int)> get periodStats {
    // Counted from the patients themselves, so the card and the lists agree.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final starts = [
      today,
      today.subtract(Duration(days: today.weekday % 7)),
      DateTime(now.year, now.month),
      DateTime(now.year),
    ];
    return [
      for (final from in starts)
        () {
          // Demo patients have no date: they count as today's.
          final list = patients.where((p) => p.createdAt == null || !p.createdAt!.isBefore(from));
          int count(String st) => list.where((p) => p.status == st).length;
          return (list.length, count('Completed'), list.length - count('Completed') - count('Sent'), count('Sent'));
        }(),
    ];
  }

  /// Card titles for today / week / month / year.
  String get periodReportsTitle => [
        tr('تقارير اليوم', 'ڕاپۆرتەکانی ئەمڕۆ', "Today's Reports"),
        tr('تقارير الأسبوع', 'ڕاپۆرتەکانی هەفتە', "This Week's Reports"),
        tr('تقارير الشهر', 'ڕاپۆرتەکانی مانگ', "This Month's Reports"),
        tr('تقارير السنة', 'ڕاپۆرتەکانی ساڵ', "This Year's Reports"),
      ][period];

  String get periodPatientsLabel => [
        tr('مرضى اليوم', 'نەخۆشانی ئەمڕۆ', 'Patients Today'),
        tr('مرضى هذا الأسبوع', 'نەخۆشانی ئەم هەفتەیە', 'Patients This Week'),
        tr('مرضى هذا الشهر', 'نەخۆشانی ئەم مانگە', 'Patients This Month'),
        tr('مرضى هذه السنة', 'نەخۆشانی ئەمساڵ', 'Patients This Year'),
      ][period];

  String get periodReportsWord => [
        tr('تقارير اليوم', 'ڕاپۆرتی ئەمڕۆ', "today's reports"),
        tr('تقارير الأسبوع', 'ڕاپۆرتی هەفتە', 'reports this week'),
        tr('تقارير الشهر', 'ڕاپۆرتی مانگ', 'reports this month'),
        tr('تقارير السنة', 'ڕاپۆرتی ساڵ', 'reports this year'),
      ][period];

  /// "Good morning" until noon, then "Good evening" (device clock).
  String get greetingNow {
    final h = DateTime.now().hour;
    return h >= 4 && h < 12
        ? tr('صباح الخير', 'بەیانی باش', 'Good Morning')
        : tr('مساء الخير', 'ئێوارە باش', 'Good Evening');
  }

  /// Today's date for the home header ("Fri, 13 Nov"), from the device clock.
  String get todayLabel {
    const ku = ['دووشەممە', 'سێشەممە', 'چوارشەممە', 'پێنجشەممە', 'هەینی', 'شەممە', 'یەکشەممە'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const ar = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    const mEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const mAr = ['كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران', 'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول'];
    final n = DateTime.now();
    return lang == 'en'
        ? '${en[n.weekday - 1]}, ${n.day} ${mEn[n.month - 1]}'
        : '${(lang == 'ku' ? ku : ar)[n.weekday - 1]}، ${n.day} ${mAr[n.month - 1]}';
  }

  /// Fetches the latest patients (orders) from the server.
  Future<void> refreshPatients() async {
    if (!LabApi.enabled || !LabApi.instance.signedIn) return;
    try {
      final list = await LabApi.instance.patients();
      patients = list;
      final sp = selectedPatient;
      if (sp != null) {
        for (final p in list) {
          if (p.id == sp.id) selectedPatient = p;
        }
      }
      notifyListeners();
    } catch (_) {/* keep what is on screen */}
  }

  void startSplash() {
    Timer(const Duration(milliseconds: 1900), () {
      splashFading = true;
      notifyListeners();
    });
    Timer(const Duration(milliseconds: 2200), skipSplash);
  }

  void skipSplash() {
    if (!splashVisible) return;
    splashFading = false;
    splashVisible = false;
    notifyListeners();
  }

  // ---- auth / navigation -------------------------------------------------
  /// 'login' | 'register' | 'otp' | 'forgot' | 'reset' | 'app'
  String auth = 'login';
  bool guest = false;

  /// 'home' | 'add' | 'results' | 'send' | 'profile' | 'print'
  String tab = 'home';

  void goAuth(String screen) {
    auth = screen;
    notifyListeners();
  }

  // Values shared between auth screens (design: XA, gt, ku, Ji, D2, ZA).
  String otpPurpose = 'register'; // 'register' | 'forgot'
  String registerPhone = '';
  String loginMethod = 'phone';
  String loginPhone = '';
  String loginEmail = '';
  String forgotMethod = 'phone';
  String forgotPhone = '';
  String forgotEmail = '';

  void goOtp(String purpose) {
    otpPurpose = purpose;
    auth = 'otp';
    notifyListeners();
  }

  String get otpTarget {
    if (otpPurpose == 'register')
      return registerPhone.isNotEmpty ? registerPhone : '+964 770 000 0000';
    if (forgotMethod == 'phone')
      return forgotPhone.isNotEmpty ? '+964 $forgotPhone' : '+964 770 000 0000';
    return forgotEmail.isNotEmpty ? forgotEmail : 'example@email.com';
  }

  void enterApp({bool asGuest = false}) {
    if (asGuest) guest = true;
    auth = 'app';
    tab = 'home';
    notifyListeners();
    _scheduleDemoNotification();
  }

  void logout() {
    if (LabApi.enabled) LabApi.instance.logout();
    auth = 'login';
    tab = 'home';
    notifyListeners();
  }

  // ---- LabGo store (labs' marketplace) ---------------------------------------
  bool storeOpen = false;
  /// Approved listings of every lab plus this lab's own (any status).
  List<MarketItem> marketItems = [];
  /// Store orders: what this lab bought, and orders other labs placed on its listings.
  List<StoreOrder> storeOrders = [];
  List<StoreOrder> storeIncoming = [];

  void openStore() {
    storeOpen = true;
    notificationsOpen = false;
    notifyListeners();
    loadMarket();
    loadStoreOrders();
  }

  void closeStore() {
    storeOpen = false;
    notifyListeners();
  }

  /// Banner slides at the top of the store (uploaded by the LabGo admin).
  List<String> storeBanners = [];
  /// Where a tap on each banner goes ('' = nowhere), same order as [storeBanners].
  List<String> storeBannerLinks = [];
  int storeBannerSeconds = 5;

  Future<void> loadMarket() async {
    if (!LabApi.enabled) return;
    try {
      final data = await LabApi.instance.market();
      marketItems = [for (final j in (data['items'] as List? ?? const [])) MarketItem.fromJson(Map<String, dynamic>.from(j as Map))];
      final slides = [for (final b in (data['banners'] as List? ?? const [])) Map<String, dynamic>.from(b as Map)].where((b) => '${b['imageUrl'] ?? ''}'.isNotEmpty).toList();
      storeBanners = [for (final b in slides) '${b['imageUrl']}'];
      storeBannerLinks = [for (final b in slides) '${b['linkUrl'] ?? ''}'];
      storeBannerSeconds = ((data['bannerSeconds'] as num?) ?? 5).toInt().clamp(2, 30);
      notifyListeners();
    } catch (_) {}
  }

  /// A new listing waits for the LabGo admin before other labs see it.
  Future<bool> addListing(MarketItem draft, List<Uint8List> images) async {
    try {
      if (LabApi.enabled) {
        final created = await LabApi.instance.addListing(draft.toFields(), images);
        marketItems = [MarketItem.fromJson(created), ...marketItems];
      } else {
        marketItems = [draft.copyWithLocal(images), ...marketItems];
      }
      notifyListeners();
      return true;
    } catch (e) {
      _serverError(e);
      return false;
    }
  }

  Future<MarketItem?> placeBid(MarketItem item, int amount) async {
    if (!LabApi.enabled) {
      toast(tr('المزايدة تعمل عند الاتصال بالسيرفر', 'مزایدە بە سێرڤەر کار دەکات', 'Bidding works when connected to the server'));
      return null;
    }
    try {
      final updated = MarketItem.fromJson(await LabApi.instance.bid(item.id, amount));
      marketItems = [for (final m in marketItems) m.id == updated.id ? updated : m];
      notifyListeners();
      toast(tr('تمت المزايدة ✓', 'مزایدە کرا ✓', 'Bid placed ✓'));
      return updated;
    } catch (e) {
      _serverError(e);
      return null;
    }
  }

  Future<void> loadStoreOrders() async {
    if (!LabApi.enabled) return;
    try {
      final data = await LabApi.instance.marketOrders();
      storeOrders = [for (final j in (data['mine'] as List? ?? const [])) StoreOrder.fromJson(Map<String, dynamic>.from(j as Map))];
      storeIncoming = [for (final j in (data['incoming'] as List? ?? const [])) StoreOrder.fromJson(Map<String, dynamic>.from(j as Map))];
      notifyListeners();
    } catch (_) {}
  }

  /// Buys a product (or asks to buy a lab for sale). The order goes to the
  /// selling lab, which is notified and moves it through the steps.
  Future<bool> placeStoreOrder(MarketItem item, {int quantity = 1, String address = '', required String phone, String note = ''}) async {
    try {
      if (LabApi.enabled) {
        final saved = await LabApi.instance.orderListing(item.id, {'quantity': quantity, 'address': address, 'phone': phone, 'note': note});
        storeOrders = [StoreOrder.fromJson(saved), ...storeOrders];
        loadMarket();
      } else {
        final n = DateTime.now();
        storeOrders = [
          StoreOrder(id: '${n.millisecondsSinceEpoch}', orderNo: 7000 + storeOrders.length + 1, kind: item.kind == 'product' ? 'purchase' : 'interest', productName: item.title, code: item.code,
              quantity: quantity, total: item.price * quantity, address: address, phone: phone, createdAt: '${n.day}/${n.month}/${n.year}', otherLab: item.labName),
          ...storeOrders,
        ];
      }
      notifyListeners();
      toast(tr('تم إرسال الطلب للمختبر البائع ✓', 'داواکاری نێردرا بۆ فرۆشیار ✓', 'Order sent to the selling lab ✓'));
      return true;
    } on ApiError catch (e) {
      toast(e.code == 'stock' ? tr('الكمية المطلوبة غير متوفرة', 'ئەم بڕە بەردەست نییە', 'Not enough in stock') : e.message);
      return false;
    } catch (_) {
      toast(tr('تعذر إرسال الطلب، تحقق من الاتصال', 'داواکاری نەنێردرا', 'Could not send the order, check the connection'));
      return false;
    }
  }

  /// Seller: next step. Buyer: cancel a new order.
  Future<void> moveStoreOrder(StoreOrder o, String status) async {
    try {
      if (LabApi.enabled) await LabApi.instance.moveMarketOrder(o.id, status);
      o.status = status;
      notifyListeners();
      if (LabApi.enabled) loadStoreOrders();
    } on ApiError catch (e) {
      toast(e.message);
    } catch (_) {
      toast(tr('تعذر التحديث', 'نوێ نەکرایەوە', 'Could not update'));
    }
  }

  /// Copies the listing's share link (paste it in WhatsApp, or in a banner's link).
  Future<void> shareListing(MarketItem m) async {
    final url = LabApi.enabled ? LabApi.instance.shareUrl(m.id) : 'https://labgo-iq.com/m/${m.id}';
    await Clipboard.setData(ClipboardData(text: '${m.title}\n$url'));
    HapticFeedback.selectionClick();
    toast(tr('تم نسخ رابط المشاركة ✓', 'بەستەری هاوبەشکردن کۆپی کرا ✓', 'Share link copied ✓'));
  }

  /// The listing a store link points to (share link /m/<id> or ?item=<id>), if it is loaded.
  MarketItem? listingForLink(String link) {
    final u = Uri.tryParse(link.trim());
    if (u == null) return null;
    final m = RegExp(r'/m/([a-fA-F0-9]{24})$').firstMatch(u.path);
    final id = m?.group(1) ?? u.queryParameters['item'];
    if (id == null) return null;
    for (final it in marketItems) {
      if (it.id == id) return it;
    }
    return null;
  }

  /// A banner link that is not a store listing opens in the browser.
  Future<void> openExternalLink(String link) async {
    final u = Uri.tryParse(link.trim());
    if (u == null || !(u.scheme == 'http' || u.scheme == 'https')) return;
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void selectTab(String id) {
    storeOpen = false;
    selectedPatient = null;
    wastePage = false;
    tab = id;
    notifyListeners();
    // Pick up changes made on the web dashboard.
    if (id == 'home' || id == 'results') refreshPatients();
    if (id == 'profile' || id == 'add') syncFromServer();
  }

  // ---- photos (user and lab logo) ------------------------------------------
  Uint8List? userPhoto;
  Uint8List? labLogo;

  Future<Uint8List?> _pickImage() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 900, maxHeight: 900, imageQuality: 85);
      return f == null ? null : await f.readAsBytes();
    } catch (_) {
      toast(tr('لا يمكن فتح الاستوديو. اسمح للتطبيق من الإعدادات.', 'ستۆدیۆ ناکرێتەوە.', 'Cannot open the photo library. Allow access in Settings.'));
      return null;
    }
  }

  Future<void> _keep(String key, Uint8List bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, base64Encode(bytes));
    } catch (_) {}
  }

  Future<void> pickUserPhoto() async {
    final bytes = await _pickImage();
    if (bytes == null) return;
    userPhoto = bytes;
    notifyListeners();
    _keep('lab.userPhoto', bytes);
    if (LabApi.enabled) {
      try {
        await LabApi.instance.uploadUserPhoto(bytes);
      } catch (e) {
        _serverError(e);
        return;
      }
    }
    toast(tr('تم تغيير الصورة ✓', 'وێنە گۆڕدرا ✓', 'Photo changed ✓'));
  }

  Future<void> pickLabLogo() async {
    final bytes = await _pickImage();
    if (bytes == null) return;
    labLogo = bytes;
    notifyListeners();
    _keep('lab.logo', bytes);
    if (LabApi.enabled) {
      try {
        await LabApi.instance.uploadLabLogo(bytes);
      } catch (e) {
        _serverError(e);
        return;
      }
    }
    toast(tr('تم تغيير شعار المختبر ✓', 'لۆگۆی تاقیگە گۆڕدرا ✓', 'Lab logo changed ✓'));
  }

  // ---- lab profile ---------------------------------------------------------
  String doctorName = 'Dr. Ahmed';
  String labDisplayName = 'LabGo Mosul';
  String profileInitial = 'A';
  String userPhone = '+964 770 000 0000';
  String userRole = 'Lab Manager';
  String userAddress = 'Mosul, Al-Majmoua St.';
  String licenseOwners = 'Dr. Ahmed Al-Mosuli, Dr. Sara Ali';
  String labEmail = 'info@labgo-mosul.iq';
  String labWebsite = '';
  String labDescription = '';
  /// "Powered by LabGo" in the report footer; only the LabGo admin can remove it.
  bool platformFooter = true;
  List<LicenseHolder> licenseHolders = [
    LicenseHolder('Dr.', 'Ahmed Al-Mosuli', 'Bacteriologist'),
    LicenseHolder('Dr.', 'Sara Ali', 'Pathologist'),
  ];

  /// Licence holders as report lines.
  List<String> get holderLines => licenseHolders.map((h) => h.line).where((l) => l.isNotEmpty).toList();

  void updateLab(void Function() change) {
    change();
    notifyListeners();
    _scheduleLabSave();
  }
  int logoBumps = 0;
  String labName = 'LabGo';
  String labPhone = '+964 770 123 4567';
  String labAddress = 'Mosul, Al-Majmoua St.';
  String labFooter = 'Thank you for choosing LabGo';

  // ---- notifications ---------------------------------------------------------
  bool notificationsOpen = false;
  final Set<String> readNotifications = {};
  int get unreadCount => notificationItems.where((n) => !readNotifications.contains(n.$1)).length;

  void openNotifications(bool open) {
    notificationsOpen = open;
    notifyListeners();
    if (open) loadNotifications();
  }

  void markRead(String id) {
    if (readNotifications.add(id) && LabApi.enabled) {
      LabApi.instance.markNotificationsRead([id]).catchError((Object _) {});
    }
    notifyListeners();
  }

  void markAllRead() {
    readNotifications.addAll(notificationItems.map((n) => n.$1));
    if (LabApi.enabled) LabApi.instance.markNotificationsRead().catchError((Object _) {});
    notifyListeners();
  }

  // ---- patients ---------------------------------------------------------------
  List<Patient> patients = LabApi.enabled ? <Patient>[] : List.of(kPatientsSeed);

  // home
  String homeFilter = 'All';
  String homeSearch = '';
  int card = 0; // stat card index 0..3
  bool cardFlipping = false;
  int period = 0; // 0 today, 1 week, 2 month, 3 year
  String peak = 'Day';

  List<Patient> get homeList => patients.where((e) {
    if (homeFilter != 'All' &&
        e.status != homeFilter &&
        !(homeFilter == 'Pending' && e.status == 'Payment Pending')) {
      return false;
    }
    if (homeSearch.isNotEmpty &&
        !e.name.toLowerCase().contains(homeSearch.toLowerCase()))
      return false;
    return true;
  }).toList();

  void setHomeFilter(String f) {
    homeFilter = f;
    notifyListeners();
  }

  void setHomeSearch(String s) {
    homeSearch = s;
    notifyListeners();
  }

  void goCard(int i) {
    final next = ((i % 4) + 4) % 4;
    if (next == card) return;
    cardFlipping = true;
    notifyListeners();
    Timer(const Duration(milliseconds: 140), () {
      card = next;
      notifyListeners();
      Timer(const Duration(milliseconds: 280), () {
        cardFlipping = false;
        notifyListeners();
      });
    });
  }

  void cyclePeriod() {
    period = (period + 1) % 4;
    notifyListeners();
  }

  void setPeak(String v) {
    peak = v;
    notifyListeners();
  }

  // results
  String resultsFilter = 'All';
  String resultsSearch = '';
  Patient? selectedPatient;
  Map<String, String> draft = {};

  List<Patient> get resultsList => patients.where((e) {
    if (resultsFilter == 'Ready' && e.status == 'Pending') return false;
    if (resultsFilter == 'Pending' && e.status != 'Pending') return false;
    if (resultsSearch.isNotEmpty) {
      final q = resultsSearch.toLowerCase();
      if (!e.name.toLowerCase().contains(q) &&
          !e.tests.join(',').toLowerCase().contains(q))
        return false;
    }
    return true;
  }).toList();

  void setResultsFilter(String f) {
    resultsFilter = f;
    notifyListeners();
  }

  void setResultsSearch(String s) {
    resultsSearch = s;
    notifyListeners();
  }

  /// Opens the result-entry screen for a patient (design `$1`).
  /// Saved results are locked until "Edit results" is tapped.
  bool resultsLocked = false;

  void unlockResults() {
    resultsLocked = false;
    notifyListeners();
  }

  /// A result uploaded as a photo or PDF (per patient), shown and sent with the result.
  final Map<String, (String, Uint8List)> resultFiles = {};
  String? _resultFileUrl(String patientId) => _uploadedUrls[patientId];
  final Map<String, String> _uploadedUrls = {};

  Future<void> uploadResultFile() async {
    final p = selectedPatient;
    if (p == null) return;
    try {
      final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png']);
      if (picked.isEmpty) return;
      final f = picked.first;
      final bytes = await f.readAsBytes();
      resultFiles[p.id] = (f.name, bytes);
      notifyListeners();
      if (LabApi.enabled) {
        final url = await LabApi.instance.uploadResultFile(p.id, bytes, f.name);
        if (url != null) _uploadedUrls[p.id] = url;
      }
      toast(tr('تم إرفاق ملف النتيجة ✓', 'فایلی ئەنجام هاوپێچکرا ✓', 'Result file attached ✓'));
    } catch (_) {
      toast(tr('تعذر رفع الملف', 'فایل بار نەکرا', 'Could not upload the file'));
    }
  }

  Future<void> openResultFile(String patientId) async {
    final f = resultFiles[patientId];
    if (f == null) return;
    if (f.$1.toLowerCase().endsWith('.pdf')) {
      await Printing.layoutPdf(name: f.$1, onLayout: (_) async => f.$2);
    } else {
      await Printing.sharePdf(bytes: await _imageToPdf(f.$2), filename: '${f.$1}.pdf');
    }
  }

  void openPatient(Patient p) {
    selectedPatient = p;
    resultsLocked = p.status == 'Completed' || p.results.values.any((v) => v.trim().isNotEmpty);
    draft = {for (final t in p.tests) t: p.results[t] ?? ''};
    tab = 'results';
    notifyListeners();
  }

  void closePatient() {
    selectedPatient = null;
    notifyListeners();
  }

  void setDraft(String test, String value) {
    draft = {...draft, test: value};
    notifyListeners();
  }

  void saveResults() {
    final sp = selectedPatient;
    if (sp == null) return;
    if (LabApi.enabled) {
      // Only what changed here, so values entered on the web meanwhile stay.
      final values = {
        for (final e in draft.entries)
          if (e.value != (sp.results[e.key] ?? '')) e.key: e.value,
      };
      if (values.isEmpty) {
        resultsLocked = true;
        toast(w('resultsSaved'));
        return;
      }
      LabApi.instance.saveResults(sp.id, values).then((_) {
        final updated = sp.copyWith(results: {...sp.results, ...values});
        patients = patients.map((m) => m.id == updated.id ? updated : m).toList();
        if (selectedPatient?.id == updated.id) selectedPatient = updated;
        resultsLocked = true;
        toast(w('resultsSaved'));
      }).catchError((Object e) {
        toast(e.toString());
      });
      return;
    }
    final updated = sp.copyWith(results: {...sp.results, ...draft});
    patients = patients.map((m) => m.id == updated.id ? updated : m).toList();
    selectedPatient = updated;
    resultsLocked = true;
        toast(w('resultsSaved'));
  }

  // print (results report or receipt)
  String printMode = 'results'; // 'results' | 'receipt'
  Patient? printPatient;
  Map<String, String> printDraft = {};
  Patient? receiptPatient;
  bool receiptPayLater = false;
  String printReturnTab = 'results';
  String printStage = 'processing'; // processing | printing | complete
  final List<Timer> _printTimers = [];

  void _startPrinting() {
    tab = 'print';
    printStage = 'processing';
    for (final t in _printTimers) {
      t.cancel();
    }
    _printTimers
      ..clear()
      ..add(
        Timer(const Duration(milliseconds: 1000), () {
          printStage = 'printing';
          notifyListeners();
          _printerFeel();
        }),
      )
      ..add(
        Timer(const Duration(milliseconds: 2750), () {
          printStage = 'complete';
          notifyListeners();
          _printDone();
        }),
      );
    notifyListeners();
  }

  /// While the paper comes out: the printer's sound and a light, steady
  /// vibration; a chime and a firm tap when it is done.
  final AudioPlayer _printSound = AudioPlayer();
  Timer? _buzz;

  void _printerFeel() {
    if (notificationsOn) {
      _printSound.stop().then((_) => _printSound.play(AssetSource('sounds/printer.wav'))).catchError((Object _) {});
    }
    _buzz?.cancel();
    var n = 0;
    _buzz = Timer.periodic(const Duration(milliseconds: 90), (t) {
      if (++n > 18 || printStage != 'printing') {
        t.cancel();
        return;
      }
      HapticFeedback.selectionClick();
      if (n % 4 == 0) HapticFeedback.lightImpact();
    });
  }

  void _printDone() {
    _buzz?.cancel();
    HapticFeedback.heavyImpact();
    if (notificationsOn) {
      _printSound.stop().then((_) => _printSound.play(AssetSource('sounds/print_done.wav'))).catchError((Object _) {});
    }
  }

  void openPrint(Patient p, Map<String, String> draftResults) {
    printMode = 'results';
    printPatient = p;
    printDraft = draftResults;
    printReturnTab = 'results';
    _startPrinting();
    _buildPrintPdf(p.copyWith(results: {...p.results, ...draftResults}));
  }

  /// The designed report (PDF) for the print screen, and a picture of its
  /// first page that the printer animation shows.
  Uint8List? printPdf;
  Uint8List? printPreview;
  int _printBuild = 0;

  Future<void> _buildPrintPdf(Patient p) async {
    final run = ++_printBuild;
    printPdf = null;
    printPreview = null;
    try {
      final bytes = await buildResultReportPdf(this, p, approved: p.status == 'Completed');
      if (run != _printBuild) return;
      printPdf = bytes;
      await for (final page in Printing.raster(bytes, pages: const [0], dpi: 144)) {
        if (run != _printBuild) return;
        printPreview = await page.toPng();
        break;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<Uint8List> _imageToPdf(Uint8List img) async => imageAsPdf(img);

  /// Home card triple-tap: print preview of the card's details.
  Future<void> printStatsCard(int index) async {
    final titles = [
      periodReportsTitle,
      tr('التقارير الشهرية', 'ڕاپۆرتی مانگانە', 'Monthly reports'),
      tr('إجمالي التقارير', 'کۆی ڕاپۆرتەکان', 'Total reports'),
      tr('النمو', 'گەشە', 'Growth'),
    ];
    HapticFeedback.mediumImpact();
    try {
      final bytes = await buildStatsPdf(this, titles[index.clamp(0, titles.length - 1)]);
      await Printing.layoutPdf(name: 'lab-statistics', onLayout: (_) async => bytes);
    } catch (_) {
      toast(tr('تعذر فتح الطباعة', 'نەتوانرا چاپ بکرێت', 'Could not open printing'));
    }
  }

  /// Report management: the device's print preview of a sample report.
  Future<void> previewSampleReport(Patient p) async {
    try {
      final bytes = await buildResultReportPdf(this, p);
      await Printing.layoutPdf(name: 'report-preview', onLayout: (_) async => bytes);
    } catch (_) {
      toast(tr('تعذر فتح المعاينة', 'نەتوانرا پێشبینین بکرێتەوە', 'Could not open the preview'));
    }
  }

  /// "Print": the report as a PDF to print or share (AirPrint, WhatsApp, Files…).
  Future<void> sharePrintPdf() async {
    final p = printPatient;
    if (p == null) return;
    if (printPdf == null) {
      await _buildPrintPdf(p.copyWith(results: {...p.results, ...printDraft}));
    }
    final bytes = printPdf;
    if (bytes == null) {
      toast(tr('تعذر إنشاء ملف PDF', 'نەتوانرا PDF دروست بکرێت', 'Could not create the PDF'));
      return;
    }
    final name = (p.permanent.isNotEmpty ? p.permanent : p.name).replaceAll(RegExp(r'[^A-Za-z0-9-]+'), '_');
    try {
      await Printing.sharePdf(bytes: bytes, filename: 'report-$name.pdf');
    } catch (_) {
      toast(tr('تعذر مشاركة الملف', 'نەتوانرا فایلەکە بڵاوبکرێتەوە', 'Could not share the file'));
    }
  }

  /// "Approve" on the result screen: every test needs a value; the server
  /// builds its report and notifies the patient (or the lab that sent the sample).
  bool approving = false;
  Future<void> approveResultsFromDetail() async {
    final p = selectedPatient;
    if (p == null || approving) return;
    final values = <String, String>{...p.results, ...draft};
    if (!resultFiles.containsKey(p.id) && p.tests.any((t) => (values[t] ?? '').trim().isEmpty)) {
      toast(tr('أكمل نتائج كل التحاليل أولاً', 'سەرەتا هەموو ئەنجامەکان پڕ بکەرەوە', 'Fill in every result first'));
      return;
    }
    approving = true;
    notifyListeners();
    try {
      if (LabApi.enabled) await LabApi.instance.approveResults(p.id, values, reportUrl: _resultFileUrl(p.id));
      final updated = p.copyWith(results: values, status: 'Completed');
      patients = patients.map((m) => m.id == p.id ? updated : m).toList();
      selectedPatient = updated;
      toast(p.id.startsWith('tr:')
          ? tr('تم الاعتماد — وصلت النتيجة إلى المختبر المرسل ✓', 'پەسەندکرا — ئەنجام گەیشتە تاقیگەی نێرەر ✓', 'Approved — the result went to the sending lab ✓')
          : tr('تم اعتماد النتيجة ✓', 'ئەنجام پەسەندکرا ✓', 'Result approved ✓'));
      if (p.id.startsWith('tr:')) {
        _loadIncoming();
      } else if (LabApi.enabled) {
        refreshPatients();
      }
      openPrint(updated, const {});
    } on ApiError catch (e) {
      toast(e.message == 'missing' ? tr('أكمل نتائج كل التحاليل أولاً', 'سەرەتا هەموو ئەنجامەکان پڕ بکەرەوە', 'Fill in every result first') : e.message);
    } catch (_) {
      toast(tr('تعذر الاعتماد، تحقق من الاتصال', 'پەسەند نەکرا، پەیوەندی بپشکنە', 'Could not approve, check the connection'));
    } finally {
      approving = false;
      notifyListeners();
    }
  }

  void openReceipt(
    Patient p, {
    required bool payLater,
    required String returnTab,
  }) {
    printMode = 'receipt';
    receiptPatient = p;
    receiptPayLater = payLater;
    printReturnTab = returnTab;
    _startPrinting();
  }

  void closePrint() {
    for (final t in _printTimers) {
      t.cancel();
    }
    _buzz?.cancel();
    _printSound.stop().catchError((Object _) {});
    tab = printReturnTab;
    notifyListeners();
  }

  /// "Print" on the receipt: the 80 mm receipt in the device's print preview.
  Future<void> printReceipt() async {
    final p = receiptPatient;
    if (p == null) return;
    HapticFeedback.mediumImpact();
    try {
      final bytes = await buildReceiptPdf(this, p, payLater: receiptPayLater);
      await Printing.layoutPdf(name: 'receipt-${p.code}', format: PdfPageFormat.roll80, onLayout: (_) async => bytes);
    } catch (_) {
      toast(tr('تعذر فتح الطباعة', 'نەتوانرا چاپ بکرێت', 'Could not open printing'));
    }
  }

  void confirmReceipt() {
    for (final t in _printTimers) {
      t.cancel();
    }
    tab = 'home';
    toast(d('receiptSent'));
  }

  // add patient form (design: ir, _f, Ju, lt, Hl, wh, tt, nu, Jf, Wh, E1, Xh, Yh, Vf)
  String addMode = 'B2C';
  String addName = '';
  String addAge = '';
  String addAgeUnit = 'Y';
  String addGender = 'Male';
  String addPhone = '';
  List<String> addTests = [];
  String addSearch = '';
  String addDoctor = '';
  bool addDoctorOpen = false;
  String addCompany = '';
  String addSample = 'Blood';
  String addUrgency = 'Normal';
  String addNotes = '';
  List<String> addPackages = [];
  bool addSaving = false;
  int addFormVersion = 0; // bumps when the form is cleared so inputs reset

  void updateAdd(void Function() change) {
    change();
    notifyListeners();
  }

  List<LabPackage> get addSelectedPackages =>
      kPackages.where((p) => addPackages.contains(p.id)).toList();

  Set<String> get addPackageTests => {
    for (final p in addSelectedPackages) ...p.tests,
  };

  List<String> get addLooseTests =>
      addTests.where((t) => !addPackageTests.contains(t)).toList();

  int get addTotal =>
      addSelectedPackages.fold(0, (a, p) => a + packagePrice(p, addMode)) +
      addLooseTests.fold(0, (a, t) => a + testPrice(t, addMode));

  List<LabPackage> get addPackageMatches {
    final q = addSearch.trim().toLowerCase();
    if (q.isEmpty) return [];
    return kPackages
        .where(
          (p) =>
              p.active &&
              !addPackages.contains(p.id) &&
              (p.name.toLowerCase().contains(q) ||
                  p.code.toLowerCase().contains(q) ||
                  p.aliases.any((a) => a.toLowerCase().contains(q)) ||
                  p.tests.any((t) => t.toLowerCase().contains(q))),
        )
        .toList();
  }

  List<CatalogTest> get addTestMatches {
    final q = addSearch.trim().toLowerCase();
    if (q.isEmpty) return [];
    return kCatalog
        .where(
          (c) =>
              c.on &&
              !addTests.contains(c.name) &&
              c.name.toLowerCase().contains(q),
        )
        .toList()
      // Names that start with what was typed come first.
      ..sort((a, b) => (a.name.toLowerCase().startsWith(q) ? 0 : 1).compareTo(b.name.toLowerCase().startsWith(q) ? 0 : 1));
  }

  // Names typed before (doctors, companies / clinics / labs) are remembered on
  // this device and suggested again; patients' records add theirs too.
  List<String> savedDoctors = [];
  List<String> savedCompanies = [];

  Future<void> loadMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      savedDoctors = prefs.getStringList('lab.doctors') ?? [];
      await _loadSupplyOrders();
      final ex = prefs.getString('lab.expenses');
      if (ex != null) localExpenses = [for (final e in (jsonDecode(ex) as List)) Map<String, dynamic>.from(e as Map)];
      lang = prefs.getString('lab.lang') ?? lang;
      final photo = prefs.getString('lab.userPhoto');
      final logo = prefs.getString('lab.logo');
      if (photo != null) userPhoto = base64Decode(photo);
      if (logo != null) labLogo = base64Decode(logo);
      savedCompanies = prefs.getStringList('lab.companies') ?? [];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _remember(String doctor, String company) async {
    List<String> push(List<String> list, String v) {
      final t = v.trim();
      if (t.isEmpty) return list;
      return [t, ...list.where((x) => x.toLowerCase() != t.toLowerCase())].take(40).toList();
    }
    savedDoctors = push(savedDoctors, doctor);
    savedCompanies = push(savedCompanies, company);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('lab.doctors', savedDoctors);
      await prefs.setStringList('lab.companies', savedCompanies);
    } catch (_) {}
  }

  static List<String> _suggest(Iterable<String> all, String typed) {
    final seen = <String>{};
    final q = typed.trim().toLowerCase();
    return [
      for (final v in all)
        if (v.trim().isNotEmpty && seen.add(v.trim().toLowerCase()) && (q.isEmpty || v.toLowerCase().contains(q)) && v.trim().toLowerCase() != q) v.trim(),
    ].take(8).toList();
  }

  List<String> get addDoctorMatches => _suggest([...savedDoctors, ...patients.map((p) => p.doctor), ...kDoctors], addDoctor);

  List<String> get addCompanyMatches => _suggest([
        ...savedCompanies,
        for (final p in patients)
          if (p.company != null) p.company!,
        for (final l in partnerLabs) l.name,
      ], addCompany);

  void togglePackage(LabPackage p) {
    if (addPackages.contains(p.id)) {
      final others = addSelectedPackages.where((o) => o.id != p.id);
      addPackages = addPackages.where((id) => id != p.id).toList();
      addTests = addTests
          .where(
            (t) =>
                !p.tests.contains(t) || others.any((o) => o.tests.contains(t)),
          )
          .toList();
    } else {
      addPackages = [...addPackages, p.id];
      addTests = {...addTests, ...p.tests}.toList();
    }
    notifyListeners();
  }

  /// Next demo order number (V0001, V0002, …) after the highest one in use.
  String _nextOrderNo() {
    var top = 0;
    for (final p in patients) {
      final n = int.tryParse(p.orderNo.replaceFirst(RegExp(r'^V'), '')) ?? 0;
      if (n > top) top = n;
    }
    return 'V${(top + 1).toString().padLeft(4, '0')}';
  }

  void submitPatient({required bool payLater}) {
    if (addName.trim().isEmpty) {
      toast(w('fillName'));
      return;
    }
    if (addSaving) return;
    if (LabApi.enabled) {
      _submitPatientToServer(payLater: payLater);
      return;
    }
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final permanent =
        'P-2026-${(842 + patients.length + 1).toString().padLeft(4, '0')}';
    final pkgs = addSelectedPackages;
    final patient = Patient(
      id: '${now.millisecondsSinceEpoch}',
      orderNo: _nextOrderNo(),
      name: addName.trim(),
      age: addAge.isNotEmpty ? '$addAge$addAgeUnit' : '—',
      gender: addGender,
      phone: addPhone.isNotEmpty ? addPhone : '+964 770 000 0000',
      tests: addTests.isNotEmpty ? List.of(addTests) : ['CBC'],
      sample: addSample,
      urgency: addUrgency,
      notes: addNotes,
      status: payLater ? 'Payment Pending' : 'Pending',
      time: time,
      price: addTotal,
      doctor: addDoctor,
      mode: addMode,
      company: addMode == 'B2B' ? addCompany : null,
      results: const {},
      permanent: permanent,
      packages: List.of(addPackages),
      packageCategory: pkgs.isNotEmpty ? pkgs.first.category : null,
    );
    patients = [patient, ...patients];
    _remember(addDoctor, addMode == 'B2B' ? addCompany : '');
    addName = '';
    addAge = '';
    addPhone = '';
    addTests = [];
    addNotes = '';
    addDoctor = '';
    addCompany = '';
    addSearch = '';
    addPackages = [];
    addFormVersion++;
    openReceipt(
      patient,
      payLater: payLater,
      returnTab: tab == 'print' ? printReturnTab : tab,
    );
  }

  Future<void> _submitPatientToServer({required bool payLater}) async {
    if (addPhone.replaceAll(RegExp(r'\D'), '').length < 10) {
      toast(tr('أدخل رقم هاتف صحيح', 'ژمارەیەکی دروست بنووسە', 'Enter a valid phone number'));
      return;
    }
    if (addTests.isEmpty) {
      toast(tr('اختر تحليلاً واحداً على الأقل', 'لانیکەم یەک پشکنین هەڵبژێرە', 'Choose at least one test'));
      return;
    }
    addSaving = true;
    notifyListeners();
    const samples = {'Blood': 'blood', 'Urine': 'urine', 'Stool': 'stool', 'Swab': 'swab', 'CSF': 'csf'};
    try {
      final orderId = await LabApi.instance.addPatient({
        'name': addName.trim(),
        'phone': LabApi.normalizePhone(addPhone),
        'age': addAge,
        'ageUnit': addAgeUnit,
        'gender': addGender == 'Female' ? 'female' : 'male',
        'doctor': addDoctor,
        'company': addMode == 'B2B' ? addCompany : '',
        'sampleType': samples[addSample] ?? 'blood',
        'urgency': addUrgency == 'Urgent' ? 'urgent' : 'routine',
        'notes': addNotes,
        'testIds': [
          for (final t in addLooseTests)
            if (testIds[t] != null) testIds[t],
        ],
        'packageIds': List.of(addPackages),
        'payLater': payLater,
      });
      _remember(addDoctor, addMode == 'B2B' ? addCompany : '');
      await refreshPatients();
      Patient? created;
      for (final p in patients) {
        if (p.id == orderId) created = p;
      }
      addName = '';
      addAge = '';
      addPhone = '';
      addTests = [];
      addNotes = '';
      addDoctor = '';
      addCompany = '';
      addSearch = '';
      addPackages = [];
      addFormVersion++;
      if (created != null) {
        openReceipt(created, payLater: payLater, returnTab: tab == 'print' ? printReturnTab : tab);
      } else {
        toast(tr('تمت إضافة المريض', 'نەخۆش زیادکرا', 'Patient added'));
      }
    } catch (e) {
      toast(e.toString());
    } finally {
      addSaving = false;
      notifyListeners();
    }
  }

  // send to other labs (design: V1, ve, qf, N1, Mu, _1, x2, Kf, dz, ru, Df, wl)
  String sendTab = 'send';
  String refPatient = '';
  String refGender = '';
  String refAge = '';

  /// Choosing a saved patient fills in their gender and age.
  void pickRefPatient(Patient p) {
    refPatient = p.name;
    refGender = p.gender == 'Female' ? 'Female' : 'Male';
    final m = RegExp(r'(\d+)\s*([YMD]?)', caseSensitive: false).firstMatch(p.age);
    final unit = (m?.group(2) ?? 'Y').toUpperCase();
    refAge = m == null ? '' : unit == 'Y' || unit.isEmpty ? m.group(1)! : '0';
    refPatientOpen = false;
    notifyListeners();
  }
  bool refPatientOpen = false;
  /// Tests chosen to send (removable chips).
  List<String> refTests = [];
  String get refTest => refTests.join(', ');

  void addRefTest(String name) {
    if (!refTests.contains(name)) refTests = [...refTests, name];
    refTestSearch = '';
    refTestOpen = false;
    updateSend(() {});
  }

  void removeRefTest(String name) {
    refTests = refTests.where((t) => t != name).toList();
    updateSend(() {});
  }
  String refTestSearch = '';
  bool refTestOpen = false;
  String refLabSearch = '';
  bool refLabOpen = false;
  String refLab = '';
  List<Referral> referrals = List.of(kReferralsSeed);
  List<PartnerLab> partnerLabs = List.of(kPartnerLabsSeed);
  String barcode = '';
  ReceivedSample? foundSample;
  List<ReceivedSample> receivedSamples = [];
  Referral? labelReferral;

  void updateSend(void Function() change) {
    final lab = refLab;
    change();
    if (refLab != lab) {
      refPriceEdited = false;
      _syncRefPrice();
    }
    if (LabApi.enabled && refTests.join(',') != _quotedTest) {
      refPriceEdited = false;
      refPrice = '';
      _quoteLabs();
    }
    notifyListeners();
  }

  List<Patient> get refPatientMatches => patients
      .where(
        (p) =>
            refPatient.trim().isEmpty ||
            p.name.toLowerCase().contains(refPatient.toLowerCase()),
      )
      .toList();

  List<CatalogTest> get refTestMatches => kCatalog
      .where(
        (c) =>
            c.on &&
            !refTests.contains(c.name) &&
            (refTestSearch.trim().isEmpty ||
                c.name.toLowerCase().contains(refTestSearch.toLowerCase())),
      )
      .toList();

  List<PartnerLab> get refLabMatches => partnerLabs
      .where(
        (l) =>
            refLabSearch.trim().isEmpty ||
            l.name.toLowerCase().contains(refLabSearch.trim().toLowerCase()),
      )
      .toList();

  void useTypedLab() {
    final name = refLabSearch.trim();
    if (name.isEmpty) return;
    final existing = partnerLabs.where(
      (l) => l.name.toLowerCase() == name.toLowerCase(),
    );
    if (existing.isNotEmpty) {
      refLab = existing.first.name;
    } else {
      partnerLabs = [PartnerLab(name, '—', '—', '—', '—'), ...partnerLabs];
      refLab = name;
    }
    refLabOpen = false;
    toast(name);
  }

  void sendReferral() {
    if (refPatient.trim().isEmpty || refTests.isEmpty) {
      toast(tr('اختر المريض والتحاليل', 'نەخۆش و پشکنین هەڵبژێرە', 'Choose the patient and tests'));
      return;
    }
    if (refLab.trim().isEmpty) {
      toast(tr('اختر المختبر الوجهة', 'تاقیگەی مەبەست هەڵبژێرە', 'Choose the destination lab'));
      return;
    }
    if (LabApi.enabled) {
      Patient? match;
      for (final p in patients) {
        if (p.name.trim().toLowerCase() == refPatient.trim().toLowerCase() && p.status != 'Completed') match = p;
      }
      final lab = refLabObj;
      LabApi.instance.addTransfer({
        if (match != null) 'orderId': match.id,
        'patientName': refPatient.trim(),
        if (refGender.isNotEmpty) 'patientGender': refGender == 'Female' ? 'female' : 'male',
        if (refAge.trim().isNotEmpty) 'patientAge': refAge.trim(),
        'testName': refTest,
        'testNames': List.of(refTests),
        'labName': refLab,
        if (lab != null && lab.id.isNotEmpty) 'toLabId': lab.id,
        if (refPriceEdited && refPrice.isNotEmpty) 'price': refPrice.replaceAll(',', ''),
      }).then((_) async {
        refPriceEdited = false;
        _clearSendForm();
        await _loadTransfers();
        toast(w('sentToast'));
      }).catchError((Object e) => _serverError(e));
      return;
    }
    referrals = [
      Referral(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        patient: refPatient.trim(),
        gender: refGender,
        age: refAge.trim(),
        test: refTest,
        lab: refLab,
        status: 'Sent',
        eta: tr('غداً', 'سبەینێ', 'Tomorrow'),
        tracking: 'LG-${DateTime.now().year}-${120 + referrals.length + 5}',
        step: 0,
      ),
      ...referrals,
    ];
    _clearSendForm();
    toast(w('sentToast'));
  }

  /// After sending, the form starts empty again.
  int refFormVersion = 0;
  void _clearSendForm() {
    refPatient = '';
    refGender = '';
    refAge = '';
    refTests = [];
    refTestSearch = '';
    refLab = '';
    refLabSearch = '';
    refPrice = '';
    refFormVersion++;
    notifyListeners();
  }

  void setBarcode(String v) {
    barcode = v;
    if (LabApi.enabled) {
      final code = v.trim().toLowerCase();
      foundSample = null;
      for (final x in incomingAll) {
        if (code.isNotEmpty && x.code.toLowerCase() == code) foundSample = x;
      }
      notifyListeners();
      return;
    }
    if (v.trim().isNotEmpty) {
      foundSample = ReceivedSample(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        code: v.trim(),
        patient: 'Ali Ahmed',
        test: 'CBC',
        lab: 'Al-Noor Clinic',
        status: 'Received',
      );
    }
    notifyListeners();
  }

  void simulateScan() {
    if (LabApi.enabled) {
      final waiting = incomingAll.where((x) => x.state == 'on_the_way');
      if (waiting.isEmpty) {
        _loadIncoming();
        toast(tr('لا توجد عينات في الطريق إليك', 'هیچ نموونەیەک لە ڕێگادا نییە', 'No samples on the way to you'));
        return;
      }
      setBarcode(waiting.first.code);
      return;
    }
    barcode = 'B2B-8842';
    foundSample = ReceivedSample(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      code: 'B2B-8842',
      patient: 'Ali Ahmed',
      test: 'CBC',
      lab: 'Al-Noor Clinic',
      status: 'Received',
    );
    notifyListeners();
  }

  void confirmReceive() {
    final s = foundSample;
    if (s == null) return;
    if (LabApi.enabled) {
      if (s.state != 'on_the_way') {
        foundSample = null;
        barcode = '';
        openIncoming(s);
        return;
      }
      LabApi.instance.receiveTransfer(s.code).then((_) async {
        foundSample = null;
        barcode = '';
        await _loadIncoming();
        toast(tr('تم استلام العينة — وصل إشعار للمختبر المرسل', 'نموونە وەرگیرا — تاقیگەی نێرەر ئاگادار کرا', 'Sample received — the sending lab was notified'));
      }).catchError((Object e) => _serverError(e));
      return;
    }
    receivedSamples = [s, ...receivedSamples];
    foundSample = null;
    barcode = '';
    toast(d('receivedToast'));
  }

  /// Server label data for the open label (null in demo mode or while loading).
  Map<String, dynamic>? labelData;

  void showLabel(Referral? r) {
    labelReferral = r;
    labelData = null;
    notifyListeners();
    if (r != null && LabApi.enabled) {
      LabApi.instance.transferLabel(r.id, lang == 'en' ? 'en' : lang).then((data) {
        if (labelReferral?.id == r.id) {
          labelData = data;
          notifyListeners();
        }
      }).catchError((Object e) => _serverError(e));
    }
  }

  /// "Print label": the device's print preview with the label PDF (same design
  /// as the server label; real QR and barcode).
  Future<void> printLabel() async {
    final r = labelReferral;
    if (r == null) return;
    final ld = labelData;
    Patient? match;
    for (final p in patients) {
      if (p.name.toLowerCase() == r.patient.toLowerCase()) match = p;
    }
    String demo() {
      if (ld != null) {
        return [
          if (ld['gender'] == 'male') tr('ذكر', 'نێر', 'Male'),
          if (ld['gender'] == 'female') tr('أنثى', 'مێ', 'Female'),
          if (ld['age'] != null) '${ld['age']} ${tr('سنة', 'ساڵ', 'y')}',
        ].join(' · ');
      }
      if (r.gender.isNotEmpty) {
        return [
          r.gender == 'Female' ? tr('أنثى', 'مێ', 'Female') : tr('ذكر', 'نێر', 'Male'),
          if (r.age.isNotEmpty) '${r.age} ${tr('سنة', 'ساڵ', 'y')}',
        ].join(' · ');
      }
      if (match == null) return '';
      return '${match.gender == 'Female' ? tr('أنثى', 'مێ', 'Female') : tr('ذكر', 'نێر', 'Male')} · ${match.age}';
    }
    final n = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final code = '${ld?['code'] ?? r.tracking}';
    final info = LabelInfo(
      code: code,
      patient: '${ld?['patient'] ?? r.patient}',
      demographic: demo(),
      tests: '${ld?['tests'] ?? r.test}',
      fromLab: '${ld?['fromLab'] ?? labDisplayName}',
      toLab: '${ld?['toLab'] ?? r.lab}',
      date: '${ld?['date'] ?? '${n.day} ${months[n.month - 1]} ${n.year}'}',
      eta: '${ld?['eta'] ?? r.eta}',
      reference: '${ld?['reference'] ?? ''}',
      price: '${ld?['priceText'] ?? ''}',
      qr: '${ld?['uploadUrl'] ?? code}',
    );
    try {
      final bytes = await buildLabelPdf(this, info);
      await Printing.layoutPdf(
        name: 'label-$code',
        format: const PdfPageFormat(100 * PdfPageFormat.mm, 70 * PdfPageFormat.mm),
        onLayout: (_) async => bytes,
      );
    } catch (_) {
      toast(tr('تعذر فتح الطباعة', 'نەتوانرا چاپ بکرێت', 'Could not open printing'));
    }
  }

  List<ReceivedSample> get receivedFiltered {
    final q = resultsSearch.toLowerCase();
    return receivedSamples
        .where(
          (e) =>
              q.isEmpty ||
              e.patient.toLowerCase().contains(q) ||
              e.test.toLowerCase().contains(q) ||
              e.lab.toLowerCase().contains(q),
        )
        .toList();
  }

  // settings (design: lr, k0, t0, e0, bl, gi, pz, zm, Fr)
  String? openSection;
  bool wastePage = false;
  bool notificationsOn = true;
  bool profileEditOpen = false;
  List<ManagedUser> users = List.of(kUsersSeed);
  List<LabRole> roles = List.of(kRolesSeed);
  String usersTab = 'users';
  List<(String, bool)> templates = [
    ('standard', true),
    ('hormonePanel', true),
    ('urgentReport', false),
  ];
  List<WasteTransfer> wasteTransfers = List.of(kWasteSeed);
  List<ProductOrder> productOrders = [];

  // ---- support (messages to the LabGo team) ---------------------------------
  List<Map<String, dynamic>> supportTickets = [];

  Future<void> loadSupport() async {
    if (!LabApi.enabled) return;
    try {
      supportTickets = [for (final t in await LabApi.instance.supportTickets()) Map<String, dynamic>.from(t as Map)];
      notifyListeners();
    } catch (_) {}
  }

  /// Sends a suggestion / bug / problem with photos; returns the ticket number.
  Future<int?> sendSupport(String type, String subject, String message, List<Uint8List> images) async {
    if (message.trim().isEmpty) {
      toast(tr('اكتب رسالتك', 'نامەکەت بنووسە', 'Write your message'));
      return null;
    }
    try {
      int no;
      if (LabApi.enabled) {
        final r = await LabApi.instance.sendSupport({'type': type, 'subject': subject, 'message': message}, images);
        no = (r['ticketNo'] as num).toInt();
        await loadSupport();
      } else {
        no = 5000 + supportTickets.length + 1;
        supportTickets = [
          {'ticketNo': no, 'type': type, 'subject': subject, 'message': message, 'status': 'open', 'adminReply': '', 'createdAt': DateTime.now().toIso8601String(), 'images': []},
          ...supportTickets,
        ];
        notifyListeners();
      }
      return no;
    } catch (e) {
      _serverError(e);
      return null;
    }
  }

  Future<List<Uint8List>> pickImages({int max = 6}) async {
    try {
      final files = await ImagePicker().pickMultiImage(maxWidth: 1400, maxHeight: 1400, imageQuality: 80, limit: max);
      return [for (final f in files.take(max)) await f.readAsBytes()];
    } catch (_) {
      toast(tr('لا يمكن فتح الاستوديو', 'ستۆدیۆ ناکرێتەوە', 'Cannot open the photo library'));
      return [];
    }
  }

  // ---- supplies orders (Create Order) ---------------------------------------
  List<SupplyOrder> supplyOrders = [];

  Future<void> _loadSupplyOrders() async {
    if (LabApi.enabled) {
      try {
        supplyOrders = [for (final j in await LabApi.instance.supplyOrders()) _supplyFromServer(j)];
        notifyListeners();
        return;
      } catch (_) {/* fall back to this device's copy */}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('lab.supplyOrders');
      if (raw != null) {
        supplyOrders = [for (final j in (jsonDecode(raw) as List)) SupplyOrder.fromJson(Map<String, dynamic>.from(j as Map))];
      }
    } catch (_) {}
  }

  /// A server order in the app's shape (date as shown on the PDF).
  SupplyOrder _supplyFromServer(Map<String, dynamic> j) {
    final d = DateTime.tryParse('${j['createdAt'] ?? ''}')?.toLocal() ?? DateTime.now();
    final need = DateTime.tryParse('${j['neededBy'] ?? ''}');
    return SupplyOrder.fromJson({
      ...j,
      'date': '${d.day}/${d.month}/${d.year}',
      'neededBy': need == null ? '' : '${need.day}/${need.month}/${need.year}',
    });
  }

  /// d/m/yyyy (as typed in the app) → yyyy-mm-dd (as stored on the server).
  static String _isoDay(String dmy) {
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(dmy.trim());
    if (m == null) return '';
    return '${m.group(3)}-${m.group(2)!.padLeft(2, '0')}-${m.group(1)!.padLeft(2, '0')}';
  }

  Future<void> saveSupplyOrder(SupplyOrder o) async {
    if (LabApi.enabled) {
      // The server gives the order its number, so the web and the app share one sequence.
      try {
        final saved = await LabApi.instance.addSupplyOrder({
          'supplier': o.supplier, 'supplierPhone': o.supplierPhone, 'neededBy': _isoDay(o.neededBy), 'notes': o.notes,
          'items': [for (final i in o.items) i.toJson()],
        });
        o = _supplyFromServer(saved);
      } on ApiError catch (e) {
        toast(e.message);
        return;
      } catch (_) {
        toast(tr('تعذر حفظ الطلب، تحقق من الاتصال', 'داواکاری پاشەکەوت نەکرا، پەیوەندی بپشکنە', 'Could not save the order, check the connection'));
        return;
      }
    }
    supplyOrders = [o, ...supplyOrders];
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lab.supplyOrders', jsonEncode([for (final x in supplyOrders.take(100)) x.toJson()]));
    } catch (_) {}
    await shareSupplyOrder(o);
  }

  int get nextSupplyOrderNo => supplyOrders.fold<int>(100, (m, o) => o.no > m ? o.no : m) + 1;

  /// The order as a PDF in the share sheet (WhatsApp, e-mail, print…).
  Future<void> shareSupplyOrder(SupplyOrder o) async {
    try {
      final bytes = await buildSupplyOrderPdf(this, o);
      await Printing.sharePdf(bytes: bytes, filename: 'supply-order-${o.no}.pdf');
    } catch (_) {
      toast(tr('تعذر إنشاء ملف PDF', 'نەتوانرا PDF دروست بکرێت', 'Could not create the PDF'));
    }
  }
  bool deleteAccountOpen = false;

  void updateSettings(void Function() change) {
    change();
    notifyListeners();
    _scheduleLabSave();
  }

  void toggleSection(String id) {
    openSection = openSection == id ? null : id;
    notifyListeners();
    if (openSection == 'financial') loadFinance();
  }

  String roleName(LabRole r) {
    final t = kRoleText[r.id];
    return t == null ? r.name : pick(t.$1);
  }

  String roleDesc(LabRole r) {
    final t = kRoleText[r.id];
    return t == null ? r.description : pick(t.$2);
  }

  void saveUser(ManagedUser u) {
    if (LabApi.enabled) {
      _saveUserOnServer(u);
      return;
    }
    final i = users.indexWhere((x) => x.id == u.id);
    users = i >= 0
        ? [for (final x in users) x.id == u.id ? u : x]
        : [...users, u];
    toast(t('userSaved'));
  }

  void deleteUser(ManagedUser u) {
    if (LabApi.enabled) {
      LabApi.instance.deleteStaff(u.id).then((_) {
        users = users.where((x) => x.id != u.id).toList();
        toast(t('userDeleted'));
      }).catchError((Object e) => _serverError(e));
      return;
    }
    users = users.where((x) => x.id != u.id).toList();
    toast(t('userDeleted'));
  }

  void toggleUserActive(ManagedUser u) {
    if (LabApi.enabled) {
      LabApi.instance.updateStaff(u.id, {'active': !u.active}).then((_) {
        users = [for (final x in users) x.id == u.id ? x.copyWith(active: !x.active) : x];
        notifyListeners();
      }).catchError((Object e) => _serverError(e));
      return;
    }
    users = [
      for (final x in users) x.id == u.id ? x.copyWith(active: !x.active) : x,
    ];
    notifyListeners();
  }

  void saveRole(LabRole r) {
    final i = roles.indexWhere((x) => x.id == r.id);
    roles = i >= 0
        ? [for (final x in roles) x.id == r.id ? r : x]
        : [...roles, r];
    toast(t('roleSaved'));
    _saveRolesSoon();
  }

  /// Returns false when the role is still assigned to a user.
  bool deleteRole(LabRole r) {
    if (users.any((u) => u.roleId == r.id)) {
      toast(t('roleInUse'));
      return false;
    }
    roles = roles.where((x) => x.id != r.id).toList();
    toast(t('roleDeleted'));
    _saveRolesSoon();
    return true;
  }

  void toggleRolePermission(LabRole r, String key) {
    final perms = r.permissions.contains(key)
        ? r.permissions.where((p) => p != key).toList()
        : [...r.permissions, key];
    roles = [
      for (final x in roles) x.id == r.id ? x.copyWith(permissions: perms) : x,
    ];
    notifyListeners();
    _saveRolesSoon();
  }

  Future<void> _saveUserOnServer(ManagedUser u) async {
    final existing = users.any((x) => x.id == u.id);
    try {
      if (existing) {
        await LabApi.instance.updateStaff(u.id, {
          'name': u.name,
          'roleKey': _roleKey(u.roleId),
          'active': u.active,
          if (u.password.isNotEmpty) 'password': u.password,
        });
      } else {
        await LabApi.instance.createStaff({
          'name': u.name,
          'phone': LabApi.normalizePhone(u.phone),
          'email': u.email,
          'password': u.password,
          'roleKey': _roleKey(u.roleId),
        });
      }
      await _loadStaff();
      toast(t('userSaved'));
    } catch (e) {
      _serverError(e);
    }
  }

  void replaceTest(CatalogTest updated) {
    final i = kCatalog.indexWhere((c) => c.name == updated.name);
    if (i >= 0) kCatalog[i] = updated;
    notifyListeners();
    // The editor saves on every change: send once typing stops.
    if (LabApi.enabled && testIds[updated.name] != null) {
      _testTimers[updated.name]?.cancel();
      _testTimers[updated.name] = Timer(const Duration(milliseconds: 900), () {
        final latest = kCatalog.firstWhere((c) => c.name == updated.name, orElse: () => updated);
        LabApi.instance
            .saveTest(_testJson(latest, id: testIds[latest.name]))
            .catchError((Object e) { _serverError(e); return <String, dynamic>{}; });
      });
    }
  }

  void addTest(CatalogTest test) {
    kCatalog.add(test);
    if (!LabApi.enabled) {
      toast(w('saved'));
      return;
    }
    notifyListeners();
    LabApi.instance.saveTest(_testJson(test)).then((data) {
      final saved = data['test'] as Map?;
      if (saved != null) testIds[test.name] = '${saved['id']}';
      toast(w('saved'));
    }).catchError((Object e) {
      kCatalog.removeWhere((c) => identical(c, test));
      notifyListeners();
      _serverError(e);
    });
  }

  void savePackage(LabPackage p) {
    final i = kPackages.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      kPackages[i] = p;
    } else {
      kPackages.add(p);
    }
    if (!LabApi.enabled) {
      toast(w('saved'));
      return;
    }
    notifyListeners();
    LabApi.instance.savePackage({
      'id': p.id,
      'name': p.name,
      'category': p.category,
      'tests': p.tests,
      'price': p.price,
      'active': p.active,
    }).then((data) {
      final id = '${data['id'] ?? p.id}';
      if (id != p.id) {
        final j = kPackages.indexWhere((x) => x.id == p.id);
        if (j >= 0) {
          kPackages[j] = LabPackage(
            id: id, code: p.code, name: p.name, category: p.category, aliases: p.aliases, tests: p.tests,
            price: p.price, priceB2B: p.priceB2B, active: p.active, isOffer: p.isOffer, oldPrice: p.oldPrice,
            startDate: p.startDate, endDate: p.endDate,
          );
        }
      }
      toast(w('saved'));
    }).catchError((Object e) {
      if (i < 0) kPackages.removeWhere((x) => x.id == p.id);
      notifyListeners();
      _serverError(e);
    });
  }

  void togglePackageActive(LabPackage p) {
    final i = kPackages.indexWhere((x) => x.id == p.id);
    if (i >= 0) kPackages[i] = p.copyWith(active: !p.active);
    notifyListeners();
    if (LabApi.enabled) {
      LabApi.instance.savePackage({'id': p.id, 'active': !p.active}).catchError((Object e) {
        if (i >= 0) kPackages[i] = p;
        notifyListeners();
        _serverError(e);
        return <String, dynamic>{};
      });
    }
  }

  final Map<String, Timer> _testTimers = {};

  Map<String, dynamic> _testJson(CatalogTest t, {String? id}) => {
    if (id != null) 'id': id,
    'name': t.name,
    'price': t.price,
    'priceB2B': t.priceB2B,
    'category': t.category,
    'on': t.on,
    'units': t.units,
    'normalText': t.normalText,
    'ranges': [
      for (final r in t.ranges)
        {'ageFrom': r.ageFrom, 'ageTo': r.ageTo, 'ageUnit': r.ageUnit, 'gender': r.gender, 'min': r.min, 'max': r.max},
    ],
  };

  void addWasteTransfer(WasteTransfer t) {
    if (LabApi.enabled) {
      () async {
        try {
          final created = await LabApi.instance.addWaste({
            'type': t.type.toLowerCase(),
            'weightKg': t.weight,
            'pickupDate': t.date,
            'notes': t.notes,
          });
          await _loadWaste();
          notifyListeners();
          final saved = wasteTransfers.where((w) => w.id == '${created['_id']}');
          if (saved.isNotEmpty) openWasteReport(saved.first);
          toast(d('transferCreated'));
        } catch (e) {
          _serverError(e);
        }
      }();
      return;
    }
    final next = wasteTransfers.fold<int>(1000, (m, w) => w.requestNo > m ? w.requestNo : m) + 1;
    final saved = WasteTransfer(id: t.id, date: t.date, type: t.type, weight: t.weight, notes: t.notes, requestNo: next);
    wasteTransfers = [saved, ...wasteTransfers];
    toast(d('transferCreated'));
    openWasteReport(saved);
  }

  /// The pickup request report (PDF) in the device's print preview: the
  /// server's report when connected, otherwise one made on the phone.
  Future<void> openWasteReport(WasteTransfer w) async {
    try {
      List<int>? bytes;
      if (LabApi.enabled) bytes = await LabApi.instance.wasteReportPdf(w.id);
      bytes ??= await buildWastePdf(this, w);
      final data = Uint8List.fromList(bytes);
      await Printing.layoutPdf(name: 'waste-request-${w.requestNo}', onLayout: (_) async => data);
    } catch (_) {
      toast(tr('تعذر فتح التقرير', 'ڕاپۆرت نەکرایەوە', 'Could not open the report'));
    }
  }

  void addProductOrder(ProductOrder o) {
    productOrders = [o, ...productOrders];
    toast(tr('تم إنشاء الطلبية', 'داواکاری دروستکرا', 'Order created'));
  }

  /// Delete account → OTP 123456 → back to Register (design `om`).
  void accountDeleted() {
    deleteAccountOpen = false;
    users = List.of(kUsersSeed);
    auth = 'register';
    authBanner = d('accountDeleted');
    notifyListeners();
  }

  // send-result sheet
  bool sendSheetOpen = false;
  Patient? sendPatient;
  String sendChannel = 'WhatsApp';
  String sendPhone = '';
  bool sending = false;
  bool sent = false;

  void openSendSheet(Patient p) {
    sendPatient = p;
    sendPhone = p.phone;
    sendChannel = 'WhatsApp';
    sent = false;
    sending = false;
    sendSheetOpen = true;
    notifyListeners();
  }

  void closeSendSheet() {
    sendSheetOpen = false;
    notifyListeners();
  }

  void setSendChannel(String c) {
    sendChannel = c;
    notifyListeners();
  }

  void setSendPhone(String v) {
    sendPhone = v;
    notifyListeners();
  }

  /// The message sent to the patient by WhatsApp / SMS: a greeting with
  /// their name, each test's value, and that the result is ready to collect.
  String resultMessage(Patient p) {
    final merged = p.copyWith(results: {...p.results, if (selectedPatient?.id == p.id) ...draft});
    final lines = [
      for (final r in resultRows(merged))
        if (r.value.trim().isNotEmpty)
          '• ${r.label}: ${r.value} ${r.units}'.trimRight() +
              switch (classify(r.value, r.normalRow)) {
                'high' => ' (${tr('مرتفع', 'بەرز', 'high')})',
                'low' => ' (${tr('منخفض', 'نزم', 'low')})',
                'normal' => ' (${tr('طبيعي', 'ئاسایی', 'normal')})',
                _ => '',
              },
    ];
    final lab = labDisplayName;
    return [
      tr('مرحباً ${p.name}،', 'سڵاو ${p.name}،', 'Hello ${p.name},'),
      tr('نتائج تحاليلك في $lab اكتملت:', 'ئەنجامی پشکنینەکانت لە $lab تەواو بوو:', 'Your test results at $lab are ready:'),
      ...lines,
      '',
      tr('يرجى الحضور إلى المختبر لاستلام النتيجة. شكراً لاختياركم $lab.', 'تکایە بۆ وەرگرتنی ئەنجام سەردانی تاقیگە بکە. سوپاس.', 'Please come to the lab to collect your result. Thank you for choosing $lab.'),
      if (labPhone.trim().isNotEmpty) '${tr('للاستفسار', 'پرسیار', 'Questions')}: $labPhone',
    ].join('\n');
  }

  Future<void> shareResultPdf(Patient p) async {
    try {
      final file = resultFiles[p.id];
      final bytes = file != null
          ? (file.$1.toLowerCase().endsWith('.pdf') ? file.$2 : await imageAsPdf(file.$2))
          : await buildResultReportPdf(this, p.copyWith(results: {...p.results, if (selectedPatient?.id == p.id) ...draft}));
      await Printing.sharePdf(bytes: bytes, filename: 'result-${intlPhone(p.phone).isEmpty ? p.id : p.name.replaceAll(' ', '_')}.pdf');
    } catch (_) {
      toast(tr('تعذر إنشاء ملف PDF', 'نەتوانرا PDF دروست بکرێت', 'Could not create the PDF'));
    }
  }

  /// "+964 770 123 4567" / "0770…" → "9647701234567".
  static String intlPhone(String phone) {
    var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith('0')) d = '964${d.substring(1)}';
    if (d.length == 10 && d.startsWith('7')) d = '964$d';
    return d;
  }

  void sendResult() {
    if (sending || sendPatient == null) return;
    final p = sendPatient!;
    // WhatsApp and SMS open the patient's chat with the message ready to send.
    if (sendChannel == 'WhatsApp' || sendChannel == 'SMS') {
      final phone = intlPhone(sendPhone.isNotEmpty ? sendPhone : p.phone);
      if (phone.length < 10) {
        toast(tr('أدخل رقم هاتف صحيح', 'ژمارەیەکی دروست بنووسە', 'Enter a valid phone number'));
        return;
      }
      final text = Uri.encodeComponent(resultMessage(p));
      final uri = sendChannel == 'WhatsApp'
          ? Uri.parse('https://wa.me/$phone?text=$text')
          : Uri.parse('sms:+$phone${defaultTargetPlatform == TargetPlatform.iOS ? '&' : '?'}body=$text');
      launchUrl(uri, mode: LaunchMode.externalApplication).then((ok) {
        if (!ok) toast(tr('تعذر فتح التطبيق', 'ئەپ نەکرایەوە', 'Could not open the app'));
        sent = ok;
        notifyListeners();
      });
      return;
    }
    // In-app: the result goes to the patient's LabGo app (approved on the server).
    sending = true;
    notifyListeners();
    if (LabApi.enabled) {
      _approveOnServer(sendPatient!);
      return;
    }
    Timer(const Duration(milliseconds: 700), () {
      sending = false;
      sent = true;
      toast(tr('تم إرسال النتيجة ✓', 'ئەنجام نێردرا ✓', 'Result sent ✓'));
    });
  }

  /// Server mode: approve (PDF + patient notification), then show "sent".
  Future<void> _approveOnServer(Patient p) async {
    final values = <String, String>{
      ...p.results,
      if (selectedPatient?.id == p.id) ...draft,
    };
    try {
      await LabApi.instance.approveResults(p.id, values);
      sent = true;
      patients = patients
          .map((m) => m.id == p.id ? m.copyWith(results: values, status: 'Completed') : m)
          .toList();
      if (selectedPatient?.id == p.id) {
        selectedPatient = selectedPatient!.copyWith(results: values, status: 'Completed');
      }
      if (p.id.startsWith('tr:')) {
        toast(tr('وصلت النتيجة إلى المختبر المرسل ✓', 'ئەنجام گەیشتە تاقیگەی نێرەر ✓', 'Result sent to the sending lab ✓'));
        _loadIncoming();
      } else {
        toast(tr('تم اعتماد النتيجة وإرسالها للمريض ✓', 'ئەنجام پەسەندکرا و نێردرا ✓', 'Result approved and sent to the patient ✓'));
        refreshPatients();
      }
    } on ApiError catch (e) {
      toast(e.message == 'missing'
          ? tr('أكمل نتائج كل التحاليل أولاً', 'سەرەتا هەموو ئەنجامەکان پڕ بکەرەوە', 'Fill in every result first')
          : e.message);
    } catch (_) {
      toast(tr('تعذر الإرسال، تحقق من الاتصال', 'نەنێردرا، پەیوەندی بپشکنە', 'Could not send, check the connection'));
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  // logout confirmation
  bool logoutOpen = false;
  void showLogout(bool v) {
    logoutOpen = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _notifTimer?.cancel();
    _syncTimer?.cancel();
    _demoNotifTimer?.cancel();
    _chime.dispose();
    _buzz?.cancel();
    _printSound.dispose();
    _labTimer?.cancel();
    _rolesTimer?.cancel();
    for (final tm in _testTimers.values) {
      tm.cancel();
    }
    for (final t in _printTimers) {
      t.cancel();
    }
    super.dispose();
  }
}

/// Gives every widget access to [AppState] and rebuilds on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Reads the state without subscribing (safe in initState).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
