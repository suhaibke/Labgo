import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../../l10n/app_localizations.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await AuthService().getUserData();
    if (mounted) {
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _getGenderLabel(String? gender) {
    switch (gender?.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return 'Not specified';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
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
          l10n.accountInfo,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray900,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 2,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.primaryColor, Color(0xFF9D94F7)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        _userData?['name']?.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Account Section
                  _SectionHeader(title: l10n.personalInformation),
                  const SizedBox(height: 12),
                  _InfoGroup(
                    children: [
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: l10n.fullName,
                        value: _userData?['name'] ?? 'Not provided',
                      ),
                      Divider(height: 1, color: AppTheme.gray200),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: l10n.emailAddress,
                        value: _userData?['email'] ?? 'Not provided',
                      ),
                      Divider(height: 1, color: AppTheme.gray200),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: l10n.phoneNumber,
                        value: _userData?['phone'] ?? 'Not provided',
                      ),
                      Divider(height: 1, color: AppTheme.gray200),
                      _InfoRow(
                        icon: Icons.cake_outlined,
                        label: l10n.dateOfBirth,
                        value: _userData?['birthDate'] != null
                            ? _formatDate(_userData!['birthDate'])
                            : 'Not provided',
                      ),
                      Divider(height: 1, color: AppTheme.gray200),
                      _InfoRow(
                        icon: Icons.wc_outlined,
                        label: l10n.gender,
                        value: _getGenderLabel(_userData?['gender']),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Account Actions
                  _SectionHeader(title: l10n.accountActions),
                  const SizedBox(height: 12),
                    _InfoGroup(
                    children: [
                      _ActionTile(
                        icon: Icons.edit_outlined,
                        title: l10n.editProfile,
                        onTap: () async {
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          );
                          if (result == true && mounted) {
                            _loadUserData();
                          }
                        },
                      ),
                      Divider(height: 1, color: AppTheme.gray200),
                      _ActionTile(
                        icon: Icons.lock_outlined,
                        title: l10n.changePassword,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ChangePasswordScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, color: AppTheme.gray200),
                      _ActionTile(
                        icon: Icons.delete_outline_rounded,
                        title: l10n.deleteAccount,
                        titleColor: AppTheme.error,
                        onTap: () async {
                          // Navigate to edit profile which has delete functionality
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          );
                          if (result == true && mounted) {
                            _loadUserData();
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),
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
        style: TextStyle(
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
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppTheme.primaryColor,
            ),
          ),

          const SizedBox(width: 14),

          // Label & Value
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
                const SizedBox(height: 2),
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

// Action Tile
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? titleColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: titleColor ?? AppTheme.primaryColor,
                ),
              ),

              const SizedBox(width: 14),

              // Title
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: titleColor ?? AppTheme.gray900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppTheme.gray300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
