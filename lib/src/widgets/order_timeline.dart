import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Vertical checklist timeline (received -> confirmed -> nurse assigned ->
/// sample collected -> at lab -> completed) matching the v2 order-tracking
/// reference design.
class OrderTimeline extends StatelessWidget {
  final String status;
  final List<dynamic>? statusHistory;

  /// Medicine-delivery orders skip the sample/lab lifecycle, so only show
  /// pending -> confirmed -> completed.
  final bool medicineFlow;

  const OrderTimeline({
    super.key,
    required this.status,
    this.statusHistory,
    this.medicineFlow = false,
  });

  static const List<String> _labSteps = [
    'pending',
    'confirmed',
    'nurse_assigned',
    'sample_collected',
    'at_lab',
    'completed',
  ];

  static const List<String> _medicineSteps = [
    'pending',
    'confirmed',
    'completed',
  ];

  List<String> get _steps => medicineFlow ? _medicineSteps : _labSteps;

  String _labelFor(String step, AppLocalizations l10n) {
    switch (step) {
      case 'pending':
        return l10n.pending;
      case 'confirmed':
        return medicineFlow ? l10n.waitingForCourier : l10n.confirmed;
      case 'nurse_assigned':
        return l10n.technicianOnTheWay;
      case 'sample_collected':
        return l10n.sampleCollected;
      case 'at_lab':
        return l10n.atLab;
      case 'completed':
        return l10n.completed;
      default:
        return step;
    }
  }

  String? _timeFor(String step) {
    if (statusHistory == null) return null;
    for (final entry in statusHistory!) {
      if (entry is Map && entry['status'] == step && entry['timestamp'] != null) {
        final parsed = DateTime.tryParse(entry['timestamp'].toString());
        if (parsed != null) return DateFormat('hh:mm a').format(parsed.toLocal());
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (status == 'cancelled') return const SizedBox.shrink();

    final currentIndex = _steps.indexOf(status).clamp(0, _steps.length - 1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(_steps.length, (index) {
          final step = _steps[index];
          final isDone = index <= currentIndex;
          final isLast = index == _steps.length - 1;
          final time = _timeFor(step);

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isDone ? AppTheme.primaryColor : AppTheme.gray200,
                        shape: BoxShape.circle,
                      ),
                      child: isDone
                          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                          : null,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isDone && index < currentIndex
                              ? AppTheme.primaryColor
                              : AppTheme.gray200,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _labelFor(step, l10n),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDone ? AppTheme.gray900 : AppTheme.gray400,
                          ),
                        ),
                        Text(
                          time ?? (isDone ? '' : l10n.soon),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
