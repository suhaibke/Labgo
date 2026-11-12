const _shareHosts = {'labgo-iq.com', 'www.labgo-iq.com'};

/// Public link for a package. Opens the app when installed; otherwise its web
/// page sends the visitor to the app store.
String packageShareUrl(String packageId) => 'https://labgo-iq.com/p/$packageId';

/// The message sent by the package share button: details and total price only.
String packageShareText({
  required String packageId,
  required String packageName,
  required List<String> testNames,
  required int price,
}) {
  final buffer = StringBuffer('باقة $packageName\n\n');
  if (testNames.isNotEmpty) {
    buffer.writeln('الفحوصات المشمولة:');
    for (final name in testNames) {
      buffer.writeln('• $name');
    }
    buffer.writeln();
  }
  buffer
    ..writeln('السعر الكلي: $price د.ع')
    ..writeln()
    ..write(packageShareUrl(packageId));
  return buffer.toString();
}

/// Extracts the package id from labgo://package/<id> (Android) or
/// https://labgo-iq.com/p/<id> (iOS Universal Links). Null for anything else.
String? packageIdFromLink(Uri uri) {
  final segments = uri.pathSegments;
  String? id;
  if (uri.scheme == 'labgo' && uri.host == 'package' && segments.length == 1) {
    id = segments[0];
  } else if (uri.scheme == 'https' &&
      _shareHosts.contains(uri.host) &&
      segments.length == 2 &&
      segments[0] == 'p') {
    id = segments[1];
  }
  return (id == null || id.isEmpty) ? null : id;
}
