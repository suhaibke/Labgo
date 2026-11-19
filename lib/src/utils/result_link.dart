const _resultHosts = {'labgo-iq.com', 'www.labgo-iq.com'};
final _codeRe = RegExp(r'^(?:[Vv]\d{1,9}-[A-HJ-NP-Za-km-z2-9]{6}|[A-HJ-NP-Za-km-z2-9]{8})$');

/// The result code from a result link the lab sent by WhatsApp / SMS or
/// printed as a QR code:
///   https://labgo-iq.com/r/V0001-k7Qm2x   (iOS Universal Link)
///   labgo://result/V0001-k7Qm2x           (Android, from the result page)
/// Null for anything else.
String? resultCodeFromLink(Uri uri) {
  final segments = uri.pathSegments;
  String? code;
  if (uri.scheme == 'labgo' && uri.host == 'result' && segments.length == 1) {
    code = segments[0];
  } else if (uri.scheme == 'https' && _resultHosts.contains(uri.host) && segments.length == 2 && segments[0] == 'r') {
    code = segments[1];
  }
  if (code == null || !_codeRe.hasMatch(code)) return null;
  return code.replaceFirst(RegExp(r'^v'), 'V');
}
