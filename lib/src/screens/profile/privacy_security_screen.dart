import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

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
          l10n.privacySecurityTitle,
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
            // Introduction Card
            _IntroCard(text: l10n.privacyIntro),

            const SizedBox(height: 24),

            // Data We Collect Section
            _ExpandableSection(
              title: l10n.dataWeCollect,
              icon: Icons.folder_outlined,
              children: [
                _InfoTile(
                  icon: Icons.person_outline_rounded,
                  title: l10n.personalInformation,
                  description: l10n.personalInfoDesc,
                ),
                _InfoTile(
                  icon: Icons.medical_information_outlined,
                  title: l10n.healthData,
                  description: l10n.healthDataDesc,
                ),
                _InfoTile(
                  icon: Icons.location_on_outlined,
                  title: l10n.locationData,
                  description: l10n.locationDataDesc,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // How We Use Data Section
            _ExpandableSection(
              title: l10n.howWeUseData,
              icon: Icons.analytics_outlined,
              children: [
                _InfoTile(
                  icon: Icons.handshake_outlined,
                  title: l10n.serviceProvision,
                  description: l10n.serviceProvisionDesc,
                ),
                _InfoTile(
                  icon: Icons.notifications_outlined,
                  title: l10n.communication,
                  description: l10n.communicationDesc,
                ),
                _InfoTile(
                  icon: Icons.trending_up_rounded,
                  title: l10n.serviceImprovement,
                  description: l10n.serviceImprovementDesc,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Data Protection Section
            _ExpandableSection(
              title: l10n.dataProtection,
              icon: Icons.security_outlined,
              children: [
                _InfoTile(
                  icon: Icons.lock_outline_rounded,
                  title: l10n.sslEncryption,
                  description: l10n.sslEncryptionDesc,
                ),
                _InfoTile(
                  icon: Icons.storage_outlined,
                  title: l10n.secureStorage,
                  description: l10n.secureStorageDesc,
                ),
                _InfoTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: l10n.accessControl,
                  description: l10n.accessControlDesc,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Your Rights Section
            _ExpandableSection(
              title: l10n.yourRights,
              icon: Icons.gavel_outlined,
              children: [
                _InfoTile(
                  icon: Icons.visibility_outlined,
                  title: l10n.rightToAccess,
                  description: l10n.rightToAccessDesc,
                ),
                _InfoTile(
                  icon: Icons.edit_outlined,
                  title: l10n.rightToCorrection,
                  description: l10n.rightToCorrectionDesc,
                ),
                _InfoTile(
                  icon: Icons.delete_outline_rounded,
                  title: l10n.rightToDeletion,
                  description: l10n.rightToDeletionDesc,
                ),
                _InfoTile(
                  icon: Icons.download_outlined,
                  title: l10n.dataPortability,
                  description: l10n.dataPortabilityDesc,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Contact Section
            _ContactCard(
              title: l10n.privacyContact,
              description: l10n.privacyContactDesc,
              email: 'info@labgo-iq.com',
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final String text;

  const _IntroCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppTheme.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray900,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: AppTheme.gray200),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: widget.children,
                  ),
                ),
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppTheme.gray600,
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

class _ContactCard extends StatelessWidget {
  final String title;
  final String description;
  final String email;

  const _ContactCard({
    required this.title,
    required this.description,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.gray600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.email_outlined,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
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
