import 'package:flutter/material.dart';

import '../services/lab_service.dart';

/// Arabic name large + English name softer underneath, matching Quick Services.
class BilingualTestName extends StatelessWidget {
  final LabTest test;
  final double arabicSize;
  final double englishSize;
  final int arabicMaxLines;
  final int englishMaxLines;
  final Color arabicColor;
  final Color englishColor;
  final FontWeight arabicWeight;
  final CrossAxisAlignment alignment;

  const BilingualTestName({
    super.key,
    required this.test,
    this.arabicSize = 15,
    this.englishSize = 11.5,
    this.arabicMaxLines = 2,
    this.englishMaxLines = 1,
    this.arabicColor = const Color(0xFF201B37),
    this.englishColor = const Color(0xFF9C9AA8),
    this.arabicWeight = FontWeight.w700,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          test.arabicName,
          maxLines: arabicMaxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: arabicSize,
            fontWeight: arabicWeight,
            color: arabicColor,
            height: 1.25,
          ),
        ),
        if (test.hasEnglishSubtitle) ...[
          const SizedBox(height: 3),
          Text(
            test.englishName,
            maxLines: englishMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: englishSize,
              fontWeight: FontWeight.w500,
              color: englishColor,
              height: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
