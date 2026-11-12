import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/nurse_service.dart';
import 'account_info_screen.dart';
import 'edit_profile_screen.dart';
import 'nurse_application_screen.dart';
import 'nurse_application_details_screen.dart';
import 'privacy_security_screen.dart';
import 'help_support_screen.dart';
import 'about_screen.dart';
import '../nurse/custody_screen.dart';
import '../../services/order_service.dart';
import '../order/location_selection_screen.dart';
import '../order/new_order_flow_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../favorites/favorites_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../widgets/auth_required_dialog.dart';
import '../../../main.dart' as main;
import '../main/main_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  NurseApplication? _nurseApplication;
  bool _isLoadingNurseApplication = true;
  String? _viewMode;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadNurseApplication();
    _loadViewMode();
  }

  Future<void> _loadUserData() async {
    final remote = await AuthService().refreshUserData();
    final userData = remote ?? await AuthService().getUserData();
    if (mounted) {
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadViewMode() async {
    final viewMode = await AuthService.getViewMode();
    if (mounted) {
      setState(() {
        _viewMode = viewMode;
      });
    }
  }

  Future<void> _loadNurseApplication() async {
    try {
      final result = await NurseService.getMyApplication();
      if (mounted && result['success'] == true) {
        final application = result['application'] as NurseApplication?;
        Map<String, dynamic>? userData = _userData;
        if (application?.isApproved == true && userData?['role'] != 'nurse') {
          userData = await AuthService().cacheUserRole('nurse');
        }
        setState(() {
          _nurseApplication = application;
          if (userData != null) _userData = userData;
          _isLoadingNurseApplication = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoadingNurseApplication = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNurseApplication = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(l10n.logout),
        content: Text(l10n.logoutConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.logout,
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService().logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  void _showLanguageBottomSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _LanguageBottomSheet(l10n: l10n),
    );
  }

  void _showCouponInfoDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.rewardsAndVouchers),
        content: const Text(
          'عندك كود خصم؟ أدخله بصفحة مراجعة الطلب قبل التأكيد وسيُطبّق الخصم مباشرة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NewOrderFlowScreen()),
              );
            },
            child: Text(l10n.newRequest),
          ),
        ],
      ),
    );
  }

  Future<void> _switchRole() async {
    await AuthService().refreshUserData();
    var latest = await AuthService().getUserData();
    if (_nurseApplication?.isApproved == true && latest?['role'] != 'nurse') {
      latest = await AuthService().cacheUserRole('nurse');
    }
    if (latest != null && mounted) {
      setState(() => _userData = latest);
    }

    final isPatientView = _viewMode != 'nurse';
    final newMode = isPatientView ? 'nurse' : 'patient';

    // Switch the view mode
    await AuthService.setViewMode(newMode);

    // Navigate to main screen with new mode
    if (mounted) {
      // Pop all the way back to MainScreen and replace it
      Navigator.of(context).popUntil((route) {
        return route.isFirst || route.settings.name == '/';
      });

      // Push new MainScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Guest mode: show login CTA instead of full profile
    if (AuthService.isGuestMode) {
      return _buildGuestProfile(context, l10n);
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 2,
                ),
              )
            : RefreshIndicator(
                onRefresh: _refreshData,
                color: AppTheme.primaryColor,
                backgroundColor: Colors.white,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Header: eyebrow + title + notification bell
                    SliverToBoxAdapter(
                      child: _ProfileTopBar(
                        title: l10n.profile,
                        onBellTap: () {
                          if (AuthService.isGuestMode) {
                            showAuthRequiredDialog(
                              context,
                              message: l10n.loginToViewNotifications,
                            );
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const NotificationsScreen(),
                              ),
                            );
                          }
                        },
                      ),
                    ),

                    // Content
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Profile Info Card
                          _ProfileInfoCard(
                            userData: _userData,
                            onTap: () async {
                              final result = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (context) => const EditProfileScreen(),
                                ),
                              );
                              if (result == true && mounted) {
                                _refreshData();
                              }
                            },
                          ),

                          const SizedBox(height: 20),

                          // Apply for Nurse Section / Role Switcher (for nurses)
                          _canUseNurseMode
                              ? _RoleSwitcherTile(
                                  isPatientView: _viewMode != 'nurse',
                                  onTap: _switchRole,
                                )
                              : _isLoadingNurseApplication
                                  ? _NurseApplicationLoadingTile()
                                  : _nurseApplication != null
                                      ? _NurseApplicationStatusTile(
                                          application: _nurseApplication!,
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => NurseApplicationDetailsScreen(
                                                  application: _nurseApplication!,
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : _ApplyForNurseTile(
                                          onTap: () async {
                                            final result = await Navigator.of(context).push<bool>(
                                              MaterialPageRoute(
                                                builder: (context) => const NurseApplicationScreen(),
                                              ),
                                            );
                                            // Reload nurse application status when returning
                                            if (result == true && mounted) {
                                              _loadNurseApplication();
                                            }
                                          },
                                        ),

                          const SizedBox(height: 28),

                          // Account Section
                          _SectionHeader(title: l10n.account),
                          const SizedBox(height: 10),
                          _SettingsTile(
                            icon: TablerIcons.user_circle,
                            title: l10n.accountInfo,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const AccountInfoScreen(),
                                ),
                              );
                            },
                          ),
                          _SettingsTile(
                            icon: TablerIcons.heart,
                            title: l10n.favorites,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const FavoritesScreen(),
                                ),
                              );
                            },
                          ),
                          _SettingsTile(
                            icon: TablerIcons.gift,
                            title: l10n.rewardsAndVouchers,
                            subtitle: 'أدخل كود الخصم عند الطلب',
                            onTap: () => _showCouponInfoDialog(context, l10n),
                          ),
                          if (_userData?['role'] == 'nurse' && _viewMode != 'patient')
                            _SettingsTile(
                              icon: TablerIcons.briefcase,
                              title: l10n.myCustody,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const CustodyScreen(),
                                  ),
                                );
                              },
                            ),
                          if (_userData?['role'] == 'nurse' && _viewMode != 'patient')
                            _SettingsTile(
                              icon: TablerIcons.map_pin,
                              title: l10n.selectLocation,
                              subtitle: (_userData?['defaultLocation']?['address'] as String?)
                                  ?.trim()
                                  .isNotEmpty ==
                                      true
                                  ? _userData!['defaultLocation']['address'] as String
                                  : null,
                              onTap: () async {
                                // Cached data can be stale (e.g. location was
                                // saved from the startup dialog after this tab
                                // was built), so fetch the latest before
                                // showing the saved pin.
                                final fresh = await AuthService().refreshUserData();
                                if (fresh != null && mounted) {
                                  setState(() => _userData = fresh);
                                }
                                if (!mounted) return;
                                final coords = _userData?['defaultLocation']?['coordinates'];
                                final result = await Navigator.of(context).push<OrderLocation>(
                                  MaterialPageRoute(
                                    builder: (context) => LocationSelectionScreen(
                                      initialLocation: coords?['latitude'] != null
                                          ? OrderLocation(
                                              address: _userData?['defaultLocation']?['address'] ?? '',
                                              latitude: (coords['latitude'] as num).toDouble(),
                                              longitude: (coords['longitude'] as num).toDouble(),
                                              landmark: _userData?['defaultLocation']?['landmark'],
                                            )
                                          : null,
                                    ),
                                  ),
                                );
                                if (result == null || !mounted) return;
                                final response = await AuthService.updateProfile(
                                  latitude: result.latitude,
                                  longitude: result.longitude,
                                  address: result.address,
                                  landmark: result.landmark,
                                );
                                if (!mounted) return;
                                if (response['success'] != true) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.failedToUpdateProfile),
                                      backgroundColor: AppTheme.error,
                                    ),
                                  );
                                  return;
                                }
                                _refreshData();
                              },
                            ),

                          const SizedBox(height: 28),

                          // Preferences Section
                          _SectionHeader(title: l10n.settings),
                          const SizedBox(height: 10),
                          _SettingsTile(
                            icon: TablerIcons.language,
                            title: l10n.language,
                            trailing: _getCurrentLanguageLabel(l10n),
                            onTap: () => _showLanguageBottomSheet(context),
                          ),
                          _SettingsTile(
                            icon: TablerIcons.map_pin,
                            title: l10n.governorate,
                            trailing: _userData?['city'] as String?,
                            onTap: () async {
                              final result = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (context) => const EditProfileScreen(),
                                ),
                              );
                              if (result == true && mounted) {
                                _refreshData();
                              }
                            },
                          ),
                          _SettingsTile(
                            icon: TablerIcons.lock,
                            title: l10n.privacySecurity,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const PrivacySecurityScreen(),
                                ),
                              );
                            },
                          ),
                          _SettingsTile(
                            icon: TablerIcons.help_circle,
                            title: l10n.helpSupport,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const HelpSupportScreen(),
                                ),
                              );
                            },
                          ),
                          _SettingsTile(
                            icon: TablerIcons.info_circle,
                            title: l10n.about,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const AboutScreen(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                        // Logout Button - Minimal
                        _LogoutButton(onTap: _logout),

                        const SizedBox(height: 48),

                        // Version Info
                        Text(
                          'LabGo v1.0.0',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.gray400,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildGuestProfile(BuildContext context, AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Image.asset(
                  'assets/images/logo.png',
                  height: 80,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),

                // Lock icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppTheme.primaryColor,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  l10n.loginToAccessProfile,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.signInForFullAccess,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.gray500,
                      ),
                ),
                const SizedBox(height: 32),

                // Sign In Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      AuthService.setGuestMode(false);
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/login',
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l10n.signIn),
                  ),
                ),

                const SizedBox(height: 16),

                // Language selector for guests
                TextButton.icon(
                  onPressed: () => _showLanguageBottomSheet(context),
                  icon: const Icon(Icons.language, size: 20),
                  label: Text(l10n.selectLanguage),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.gray600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canUseNurseMode =>
      _userData?['role'] == 'nurse' || _nurseApplication?.isApproved == true;

  Future<void> _refreshData() async {
    await Future.wait([
      _loadUserData(),
      _loadNurseApplication(),
      _loadViewMode(),
    ]);
  }

  String _getCurrentLanguageLabel(AppLocalizations l10n) {
    final locale = Localizations.localeOf(context);
    switch (locale.languageCode) {
      case 'ar':
        return 'العربية';
      case 'ku':
        return 'Kurdî';
      case 'tr':
        return 'Türkçe';
      default:
        return 'English';
    }
  }
}

// Top bar: small purple eyebrow label + page title + notification bell.
class _ProfileTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBellTap;

  const _ProfileTopBar({required this.title, required this.onBellTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR LABGO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.gray900,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onBellTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gray900.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: AppTheme.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Profile info card: avatar/icon (left), name + member-since/role (middle),
// chevron (right).
class _ProfileInfoCard extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback? onTap;

  const _ProfileInfoCard({this.userData, this.onTap});

  static const _iconBg = Color(0xFFEEEDFE);

  static const _arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  String? _memberSince(AppLocalizations l10n) {
    final createdAt = userData?['createdAt'] as String?;
    if (createdAt == null || createdAt.isEmpty) return null;
    final date = DateTime.tryParse(createdAt);
    if (date == null) return null;
    return '${l10n.memberSincePrefix} ${_arabicMonths[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = userData?['name'] ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final profilePicture = ApiService.resolveMediaUrl(userData?['profilePicture'] as String?);
    final isNurse = userData?['role'] == 'nurse';
    final roleLabel = isNurse ? 'ممرض' : 'مريض';
    final memberSince = _memberSince(l10n);
    final averageRating = (userData?['averageRating'] ?? 0.0).toDouble();
    final totalRatings = userData?['totalRatings'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gray900.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Chevron (right in RTL)
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.gray300,
              ),

              const SizedBox(width: 8),

              // Name / member-since / rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gray900,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      memberSince != null ? '$memberSince · $roleLabel' : roleLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.gray500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isNurse && totalRatings > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppTheme.secondaryColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${averageRating.toStringAsFixed(1)} ($totalRatings)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Avatar (left in RTL)
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: _iconBg,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: (profilePicture != null && profilePicture.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: profilePicture,
                        fit: BoxFit.cover,
                        width: 48,
                        height: 48,
                        errorWidget: (context, url, error) => Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      )
                    : const Icon(
                        TablerIcons.user,
                        size: 22,
                        color: AppTheme.primaryColor,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Section Header - Apple Style
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

// Settings Tile - white card, icon-left, chevron-right, optional subtitle.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  static const _iconBg = Color(0xFFEEEDFE);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gray900.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Chevron (right in RTL)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.gray300,
                ),

                const SizedBox(width: 6),

                // Title / subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.gray900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.gray500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Trailing label
                if (trailing != null && trailing!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    trailing!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.gray400,
                    ),
                  ),
                ],

                const SizedBox(width: 10),

                // Icon (left in RTL)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Logout Button - Minimal
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.error.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: const Center(
            child: Text(
              'Log Out',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.error,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Language Bottom Sheet
class _LanguageBottomSheet extends StatelessWidget {
  final AppLocalizations l10n;

  const _LanguageBottomSheet({required this.l10n});

  static const Map<String, Locale> _languages = {
    'English': Locale('en'),
    'العربية': Locale('ar'),
    'Kurdî': Locale('ku'),
    'Türkçe': Locale('tr'),
  };

  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppTheme.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    l10n.selectLanguage,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppTheme.gray400,
                    ),
                  ),
                ],
              ),
            ),

            // Language Options
            ..._languages.entries.map((entry) {
              final isSelected = currentLocale.languageCode == entry.value.languageCode;
              return _LanguageOption(
                label: entry.key,
                isSelected: isSelected,
                onTap: () {
                  final appState = main.LabGoApp.of(context);
                  appState?.setLocale(entry.value);
                  Navigator.pop(context);
                },
              );
            }).toList(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Language Option
class _LanguageOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.gray700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Apply for Nurse Tile - Featured
class _ApplyForNurseTile extends StatelessWidget {
  final VoidCallback onTap;

  const _ApplyForNurseTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryColor, AppTheme.primaryDark],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 14),

              // Text Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.applyForNurse,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.joinHealthcareTeam,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'مريض',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Nurse Application Loading Tile
class _NurseApplicationLoadingTile extends StatelessWidget {
  const _NurseApplicationLoadingTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.15),
            const Color(0xFF9D94F7).withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Checking application status...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.gray700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Nurse Application Status Tile
class _NurseApplicationStatusTile extends StatelessWidget {
  final NurseApplication application;
  final VoidCallback onTap;

  const _NurseApplicationStatusTile({
    required this.application,
    required this.onTap,
  });

  String _getStatusText(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.pending;
      case 'under_review':
        return l10n.underReview;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = application.status;
    final statusText = _getStatusText(status, l10n);
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 72,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 12),

                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.applyForNurse,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gray900,
                        fontSize: 14,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: statusColor.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// Role Switcher Tile - for nurses to switch to patient view and back
class _RoleSwitcherTile extends StatelessWidget {
  final bool isPatientView;
  final VoidCallback onTap;

  const _RoleSwitcherTile({
    required this.isPatientView,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isPatientView
                  ? [Colors.orange, Colors.deepOrange]
                  : [AppTheme.primaryColor, AppTheme.primaryDark],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPatientView ? Icons.local_hospital_rounded : Icons.person_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 14),

              // Text Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPatientView ? l10n.switchToNurseView : l10n.switchToPatientView,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPatientView
                          ? l10n.switchToNurseViewSubtitle
                          : l10n.switchToPatientViewSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPatientView ? 'مريض' : 'ممرض',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
