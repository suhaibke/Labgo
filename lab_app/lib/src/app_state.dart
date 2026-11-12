import 'dart:async';

import 'package:flutter/material.dart';

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
    tab = id;
    notifyListeners();
  }

  // ---- lab profile ---------------------------------------------------------
  String doctorName = 'Dr. Ahmed';
  String labDisplayName = 'LabGo Mosul';
  String profileInitial = 'A';
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

  // print (results report)
  Patient? printPatient;
  Map<String, String> printDraft = {};
  String printStage = 'processing'; // processing | printing | complete
  final List<Timer> _printTimers = [];

  void openPrint(Patient p, Map<String, String> draftResults) {
    printPatient = p;
    printDraft = draftResults;
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

  void closePrint() {
    for (final t in _printTimers) {
      t.cancel();
    }
    tab = 'results';
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
