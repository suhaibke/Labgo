import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app_state.dart';
import '../ui.dart';

/// Full-screen camera that reads a sample's barcode or QR code and returns it.
/// A QR from a LabGo label holds the upload link; the sample code is its last
/// part, so both forms are accepted.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  static Future<String?> open(BuildContext context) => Navigator.of(context).push<String>(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ScanScreen()),
      );

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.code39, BarcodeFormat.ean13],
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String codeFrom(String raw) {
    final v = raw.trim();
    final m = RegExp(r'LG-\d{4}-[A-Z0-9]+', caseSensitive: false).firstMatch(v);
    return m != null ? m.group(0)!.toUpperCase() : v;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(context);
    final hole = MediaQuery.sizeOf(context).width * .72;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_done) return;
              for (final b in capture.barcodes) {
                final raw = b.rawValue ?? '';
                if (raw.isEmpty) continue;
                _done = true;
                Navigator.of(context).pop(codeFrom(raw));
                return;
              }
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  app.tr('لا يمكن فتح الكاميرا. اسمح للتطبيق باستخدامها من الإعدادات.', 'کامێرا ناکرێتەوە. لە ڕێکخستنەکان ڕێگە بدە.', 'The camera cannot open. Allow camera access in Settings.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
          ),
          // frame
          Center(
            child: Container(
              width: hole,
              height: hole * .7,
              decoration: BoxDecoration(
                border: Border.all(color: app.palette.accent, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _round(const LIcon('X', size: 20, color: Colors.white), () => Navigator.of(context).pop()),
                      const Spacer(),
                      _round(const LIcon('Flashlight', size: 20, color: Colors.white), () => _controller.toggleTorch()),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      app.tr('وجّه الكاميرا إلى باركود أو QR العينة', 'کامێرا ئاراستەی بارکۆدی نموونە بکە', 'Point the camera at the sample barcode or QR'),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _round(Widget child, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: child,
        ),
      );
}
