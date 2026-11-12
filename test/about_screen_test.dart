import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:labgo_app/l10n/app_localizations.dart';
import 'package:labgo_app/src/screens/profile/about_screen.dart';

void main() {
  testWidgets('About credits LabGo LLC without personal contact details',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'LabGo',
      packageName: 'com.labgollc.labgo',
      version: '1.0.1',
      buildNumber: '4',
      buildSignature: '',
    );

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AboutScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LabGo LLC'), findsOneWidget);
    expect(
      find.text('تم تطوير هذا التطبيق من قبل شركة LabGo LLC'),
      findsOneWidget,
    );
    expect(find.text('محمد ماجد'), findsNothing);
    expect(find.text('07710249070'), findsNothing);
  });
}
