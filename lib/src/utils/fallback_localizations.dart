import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Custom localization delegate that provides fallback for unsupported locales
class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  static const List<Locale> _supportedLocales = [
    Locale('ar'),
    Locale('en'),
    Locale('tr'),
  ];

  @override
  bool isSupported(Locale locale) {
    // Support all locales - we'll provide fallback
    return true;
  }

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // For Kurdish, use Arabic localizations as fallback
    if (locale.languageCode == 'ku') {
      return GlobalMaterialLocalizations.delegate.load(const Locale('ar'));
    }
    return GlobalMaterialLocalizations.delegate.load(locale);
  }

  @override
  bool shouldReload(FallbackMaterialLocalizationsDelegate old) => false;
}

/// Custom Cupertino localization delegate with fallback support
class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return true;
  }

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    if (locale.languageCode == 'ku') {
      return GlobalCupertinoLocalizations.delegate.load(const Locale('ar'));
    }
    return GlobalCupertinoLocalizations.delegate.load(locale);
  }

  @override
  bool shouldReload(FallbackCupertinoLocalizationsDelegate old) => false;
}
