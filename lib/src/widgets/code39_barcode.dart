import 'package:flutter/material.dart';

class Code39Barcode extends StatelessWidget {
  final String data;
  final Color color;

  const Code39Barcode({
    super.key,
    required this.data,
    this.color = const Color(0xFF1C1433),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: Code39Painter(data: data, color: color),
      size: Size.infinite,
    );
  }
}

class Code39Painter extends CustomPainter {
  final String data;
  final Color color;

  const Code39Painter({required this.data, this.color = const Color(0xFF1C1433)});

  static const _patterns = <String, String>{
    '0': 'nnnwwnwnn',
    '1': 'wnnwnnnnw',
    '2': 'nnwwnnnnw',
    '3': 'wnwwnnnnn',
    '4': 'nnnwwnnnw',
    '5': 'wnnwwnnnn',
    '6': 'nnwwwnnnn',
    '7': 'nnnwnnwnw',
    '8': 'wnnwnnwnn',
    '9': 'nnwwnnwnn',
    'A': 'wnnnnwnnw',
    'B': 'nnwnnwnnw',
    'C': 'wnwnnwnnn',
    'D': 'nnnnwwnnw',
    'E': 'wnnnwwnnn',
    'F': 'nnwnwwnnn',
    'G': 'nnnnnwwnw',
    'H': 'wnnnnwwnn',
    'I': 'nnwnnwwnn',
    'J': 'nnnnwwwnn',
    'K': 'wnnnnnnww',
    'L': 'nnwnnnnww',
    'M': 'wnwnnnnwn',
    'N': 'nnnnwnnww',
    'O': 'wnnnwnnwn',
    'P': 'nnwnwnnwn',
    'Q': 'nnnnnnwww',
    'R': 'wnnnnnwwn',
    'S': 'nnwnnnwwn',
    'T': 'nnnnwnwwn',
    'U': 'wwnnnnnnw',
    'V': 'nwwnnnnnw',
    'W': 'wwwnnnnnn',
    'X': 'nwnnwnnnw',
    'Y': 'wwnnwnnnn',
    'Z': 'nwwnwnnnn',
    '-': 'nwnnnnwnw',
    '.': 'wwnnnnwnn',
    ' ': 'nwwnnnwnn',
    '*': 'nwnnwnwnn',
    '\$': 'nwnwnwnnn',
    '/': 'nwnwnnnwn',
    '+': 'nwnnnwnwn',
    '%': 'nnnwnwnwn',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final encoded =
        '*${data.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-\. \$/+%]'), '')}*';
    final modules = <bool>[];
    for (var i = 0; i < encoded.length; i++) {
      final pattern = _patterns[encoded[i]] ?? _patterns['0']!;
      for (var j = 0; j < pattern.length; j++) {
        final wide = pattern[j] == 'w';
        final isBar = j.isEven;
        final units = wide ? 3 : 1;
        for (var u = 0; u < units; u++) {
          modules.add(isBar);
        }
      }
      if (i != encoded.length - 1) {
        modules.add(false);
      }
    }

    if (modules.isEmpty) return;

    // A blank quiet zone on both sides (roughly 10 narrow-bar widths) is
    // required for scanners to reliably find the start/stop markers -
    // without it bars printed edge-to-edge get misread.
    const quietModules = 10;
    final totalModules = modules.length + quietModules * 2;
    final paint = Paint()..color = color;
    // Snap every bar edge to a whole pixel instead of a fractional `i *
    // unit` offset: fractional offsets let rounding error accumulate
    // across the barcode, blurring edges and skewing the narrow:wide bar
    // ratio scanners rely on to tell modules apart.
    for (var i = 0; i < modules.length; i++) {
      if (!modules[i]) continue;
      final x0 = (((i + quietModules) / totalModules) * size.width).roundToDouble();
      final x1 = (((i + quietModules + 1) / totalModules) * size.width).roundToDouble();
      canvas.drawRect(
        Rect.fromLTWH(x0, 0, (x1 - x0).clamp(1, size.width), size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant Code39Painter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}
