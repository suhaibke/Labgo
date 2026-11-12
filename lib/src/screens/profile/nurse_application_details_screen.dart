import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/nurse_service.dart';
import '../../../l10n/app_localizations.dart';
import 'nurse_application_screen.dart';

class NurseApplicationDetailsScreen extends StatelessWidget {
  final NurseApplication application;

  const NurseApplicationDetailsScreen({
    super.key,
    required this.application,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.gray900,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.applyForNurse,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray900,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _StatusCard(application: application),
            const SizedBox(height: 32),

            // Rejection Reason (if rejected)
            if (application.status == 'rejected' && application.reviewDetails != null && application.reviewDetails!['rejectionReason'] != null) ...[
              _SectionHeader(title: l10n.rejectionReason),
              const SizedBox(height: 12),
              _InfoGroup(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFFF3B30),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            application.reviewDetails!['rejectionReason'].toString(),
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.gray900,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Reapply Button
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NurseApplicationScreen(),
                        ),
                      );
                      if (result == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_circle_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.reapplyForNurse,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Personal Information Section
            _SectionHeader(title: l10n.personalInformation),
            const SizedBox(height: 12),
            _InfoGroup(
              children: [
                _InfoRow(label: l10n.fullName, value: application.personalInfo['name'] ?? ''),
                const Divider(height: 1, color: AppTheme.gray200),
                _InfoRow(label: l10n.emailAddress, value: application.personalInfo['email'] ?? ''),
                const Divider(height: 1, color: AppTheme.gray200),
                _InfoRow(label: l10n.phoneNumber, value: application.personalInfo['phone'] ?? ''),
              ],
            ),
            const SizedBox(height: 32),

            // Location Section
            _SectionHeader(title: l10n.location),
            const SizedBox(height: 12),
            _InfoGroup(
              children: [
                _InfoRow(label: l10n.city, value: application.location.city),
                const Divider(height: 1, color: AppTheme.gray200),
                _InfoRow(label: l10n.zone, value: application.location.zone),
                if (application.location.address != null && application.location.address!.isNotEmpty) ...[
                  const Divider(height: 1, color: AppTheme.gray200),
                  _InfoRow(label: l10n.address, value: application.location.address!),
                ],
              ],
            ),
            const SizedBox(height: 32),

            // Questionnaire Section
            _SectionHeader(title: l10n.questionnaire),
            const SizedBox(height: 12),
            _InfoGroup(
              children: [
                _BooleanRow(
                  label: l10n.ownsCarQuestion,
                  value: application.questionnaire.ownsCar,
                ),
                const Divider(height: 1, color: AppTheme.gray200),
                _BooleanRow(
                  label: l10n.isEmployedQuestion,
                  value: application.questionnaire.isEmployed,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Additional Info
            if (application.additionalInfo != null && application.additionalInfo!.isNotEmpty) ...[
              _SectionHeader(title: l10n.additionalInfo),
              const SizedBox(height: 12),
              _InfoGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      application.additionalInfo!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.gray700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],

            // Submitted Date
            _InfoGroup(
              children: [
                _InfoRow(
                  label: l10n.submitted,
                  value: _formatDate(application.submittedAt, l10n),
                ),
              ],
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return l10n.today;
    } else if (difference.inDays == 1) {
      return l10n.yesterday;
    } else if (difference.inDays < 7) {
      return l10n.daysAgo(difference.inDays);
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Status Card
class _StatusCard extends StatelessWidget {
  final NurseApplication application;

  const _StatusCard({required this.application});

  String _getStatusText(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.pending;
      case 'under_review':
        return l10n.inProgress;
      case 'approved':
        return l10n.completed;
      case 'rejected':
        return l10n.cancelled;
      case 'on_hold':
        return 'On Hold';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF4A900); // Gold
      case 'under_review':
        return const Color(0xFF2196F3); // Blue
      case 'approved':
        return const Color(0xFF34C759); // Green
      case 'rejected':
        return const Color(0xFFFF3B30); // Red
      case 'on_hold':
        return const Color(0xFF8E8E93); // Gray
      default:
        return const Color(0xFFF4A900);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'under_review':
        return Icons.search;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'on_hold':
        return Icons.pause_circle;
      default:
        return Icons.info;
    }
  }

  String _getStatusDescription(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.applicationPending;
      case 'under_review':
        return l10n.applicationUnderReviewDesc;
      case 'approved':
        return l10n.applicationApproved;
      case 'rejected':
        return l10n.applicationRejected;
      case 'on_hold':
        return l10n.applicationOnHold;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = application.status;
    final statusText = _getStatusText(status, l10n);
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final statusDescription = _getStatusDescription(status, l10n);

    return Container(
      constraints: const BoxConstraints(
        minHeight: 88,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Icon Container
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 28,
              ),
            ),

            const SizedBox(width: 16),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      fontSize: 16,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusDescription,
                    style: TextStyle(
                      color: AppTheme.gray600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Section Header
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.gray400,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// Info Group
class _InfoGroup extends StatelessWidget {
  final List<Widget> children;

  const _InfoGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

// Info Row
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.gray400,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.gray900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Boolean Row
class _BooleanRow extends StatelessWidget {
  final String label;
  final bool value;

  const _BooleanRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.gray400,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ? l10n.yes : l10n.no,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
