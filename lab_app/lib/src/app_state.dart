import 'dart:async';

import 'package:flutter/material.dart';

import 'catalog_data.dart';
import 'models.dart';
import 'strings_data.dart';
import 'theme.dart';

/// Single app-wide state, mirroring the design's root component.
/// Everything is local sample data (phase 1 — no server calls).
class AppState extends ChangeNotifier {
  // ---- appearance -------------------------------------------------------
  String lang = 'en';
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
  }

  void logout() {
    auth = 'login';
    tab = 'home';
    notifyListeners();
  }

  void selectTab(String id) {
    selectedPatient = null;
    wastePage = false;
    tab = id;
    notifyListeners();
  }

  // ---- lab profile ---------------------------------------------------------
  String doctorName = 'Dr. Ahmed';
  String labDisplayName = 'LabGo Mosul';
  String profileInitial = 'A';
  String userPhone = '+964 770 000 0000';
  String userRole = 'Lab Manager';
  String userAddress = 'Mosul, Al-Majmoua St.';
  String licenseOwners = 'Dr. Ahmed Al-Mosuli, Dr. Sara Ali';
  int logoBumps = 0;
  String labName = 'LabGo';
  String labPhone = '+964 770 123 4567';
  String labAddress = 'Mosul, Al-Majmoua St.';
  String labFooter = 'Thank you for choosing LabGo';

  // ---- notifications ---------------------------------------------------------
  bool notificationsOpen = false;
  final Set<String> readNotifications = {};
  int get unreadCount => 3 - readNotifications.length;

  void openNotifications(bool open) {
    notificationsOpen = open;
    notifyListeners();
  }

  void markRead(String id) {
    readNotifications.add(id);
    notifyListeners();
  }

  void markAllRead() {
    readNotifications.addAll(['n1', 'n2', 'n3']);
    notifyListeners();
  }

  // ---- patients ---------------------------------------------------------------
  List<Patient> patients = List.of(kPatientsSeed);

  // home
  String homeFilter = 'All';
  String homeSearch = '';
  int card = 0; // stat card index 0..3
  bool cardFlipping = false;
  int period = 0; // 0 today, 1 week, 2 month
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
    period = (period + 1) % 3;
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
  void openPatient(Patient p) {
    selectedPatient = p;
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
    final updated = sp.copyWith(results: {...sp.results, ...draft});
    patients = patients.map((m) => m.id == updated.id ? updated : m).toList();
    selectedPatient = updated;
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
        }),
      )
      ..add(
        Timer(const Duration(milliseconds: 2750), () {
          printStage = 'complete';
          notifyListeners();
        }),
      );
    notifyListeners();
  }

  void openPrint(Patient p, Map<String, String> draftResults) {
    printMode = 'results';
    printPatient = p;
    printDraft = draftResults;
    printReturnTab = 'results';
    _startPrinting();
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
    tab = printReturnTab;
    notifyListeners();
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
        .toList();
  }

  List<String> get addDoctorMatches => kDoctors
      .where(
        (d) =>
            addDoctor.trim().isEmpty ||
            d.toLowerCase().contains(addDoctor.toLowerCase()),
      )
      .toList();

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

  void submitPatient({required bool payLater}) {
    if (addName.trim().isEmpty) {
      toast(w('fillName'));
      return;
    }
    if (addSaving) return;
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final permanent =
        'P-2026-${(842 + patients.length + 1).toString().padLeft(4, '0')}';
    final pkgs = addSelectedPackages;
    final patient = Patient(
      id: '${now.millisecondsSinceEpoch}',
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

  // send to other labs (design: V1, ve, qf, N1, Mu, _1, x2, Kf, dz, ru, Df, wl)
  String sendTab = 'send';
  String refPatient = 'Sara Ali';
  bool refPatientOpen = false;
  String refTest = 'Vitamin D';
  String refTestSearch = '';
  bool refTestOpen = false;
  String refLabSearch = '';
  bool refLabOpen = false;
  String refLab = 'Al-Noor Lab';
  List<Referral> referrals = List.of(kReferralsSeed);
  List<PartnerLab> partnerLabs = List.of(kPartnerLabsSeed);
  String barcode = '';
  ReceivedSample? foundSample;
  List<ReceivedSample> receivedSamples = [];
  Referral? labelReferral;

  void updateSend(void Function() change) {
    change();
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
    if (refPatient.trim().isEmpty || refTest.isEmpty) return;
    referrals = [
      Referral(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        patient: refPatient.trim(),
        test: refTest,
        lab: refLab,
        status: 'Sent',
        eta: 'Tomorrow 2pm',
        tracking: 'LG-2026-${120 + referrals.length + 5}',
        step: 0,
      ),
      ...referrals,
    ];
    toast(w('sentToast'));
  }

  void setBarcode(String v) {
    barcode = v;
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
    receivedSamples = [s, ...receivedSamples];
    foundSample = null;
    barcode = '';
    toast(d('receivedToast'));
  }

  void showLabel(Referral? r) {
    labelReferral = r;
    notifyListeners();
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
  bool deleteAccountOpen = false;

  void updateSettings(void Function() change) {
    change();
    notifyListeners();
  }

  void toggleSection(String id) {
    openSection = openSection == id ? null : id;
    notifyListeners();
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
    final i = users.indexWhere((x) => x.id == u.id);
    users = i >= 0
        ? [for (final x in users) x.id == u.id ? u : x]
        : [...users, u];
    toast(t('userSaved'));
  }

  void deleteUser(ManagedUser u) {
    users = users.where((x) => x.id != u.id).toList();
    toast(t('userDeleted'));
  }

  void toggleUserActive(ManagedUser u) {
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
  }

  /// Returns false when the role is still assigned to a user.
  bool deleteRole(LabRole r) {
    if (users.any((u) => u.roleId == r.id)) {
      toast(t('roleInUse'));
      return false;
    }
    roles = roles.where((x) => x.id != r.id).toList();
    toast(t('roleDeleted'));
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
  }

  void replaceTest(CatalogTest updated) {
    final i = kCatalog.indexWhere((c) => c.name == updated.name);
    if (i >= 0) kCatalog[i] = updated;
    notifyListeners();
  }

  void addTest(CatalogTest test) {
    kCatalog.add(test);
    toast(w('saved'));
  }

  void savePackage(LabPackage p) {
    final i = kPackages.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      kPackages[i] = p;
    } else {
      kPackages.add(p);
    }
    toast(w('saved'));
  }

  void togglePackageActive(LabPackage p) {
    final i = kPackages.indexWhere((x) => x.id == p.id);
    if (i >= 0) kPackages[i] = p.copyWith(active: !p.active);
    notifyListeners();
  }

  void addWasteTransfer(WasteTransfer t) {
    wasteTransfers = [t, ...wasteTransfers];
    toast(d('transferCreated'));
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

  void sendResult() {
    if (sending || sendPatient == null) return;
    sending = true;
    notifyListeners();
    Timer(const Duration(milliseconds: 700), () {
      sending = false;
      sent = true;
      toast(tr('تم إرسال النتيجة ✓', 'ئەنجام نێردرا ✓', 'Result sent ✓'));
    });
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
