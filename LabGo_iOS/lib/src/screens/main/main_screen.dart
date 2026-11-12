import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import '../search/search_screen.dart';
import '../test_results/test_results_screen.dart';
import '../profile/profile_screen.dart';
import '../nurse/nurse_available_orders_screen.dart';
import '../nurse/nurse_my_orders_screen.dart';
import '../nurse/nurse_finance_screen.dart';
import '../../../l10n/app_localizations.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  String? _userRole;
  String? _viewMode;
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _isGuest = AuthService.isGuestMode;
    if (!_isGuest) {
      _loadUserRole();
    }
  }

  Future<void> _loadUserRole() async {
    final userData = await AuthService().getUserData();
    final viewMode = await AuthService.getViewMode();
    if (userData != null && mounted) {
      setState(() {
        _userRole = userData['role'];
        _viewMode = viewMode;
      });
    }
  }

  /// Get the effective role for UI (respects view mode for nurses)
  String? get _effectiveRole {
    if (_userRole == 'nurse' && _viewMode == 'patient') {
      return 'patient';
    }
    return _userRole;
  }

  List<Widget> _getScreens() {
    if (_isGuest) {
      return const [
        HomeTabScreen(),
        SearchScreen(),
        ProfileScreen(),
      ];
    }
    if (_effectiveRole == 'nurse') {
      return const [
        NurseAvailableOrdersScreen(),
        NurseMyOrdersScreen(),
        NurseFinanceScreen(),
        ProfileScreen(),
      ];
    }
    return const [
      HomeTabScreen(),
      SearchScreen(),
      TestResultsScreen(),
      ProfileScreen(),
    ];
  }

  List<_NavItemData> _getNavItems(AppLocalizations l10n) {
    if (_effectiveRole == 'nurse') {
      return [
        _NavItemData(
          icon: Icons.assignment_rounded,
          activeIcon: Icons.assignment_rounded,
          label: l10n.availableOrders,
        ),
        _NavItemData(
          icon: Icons.receipt_long_rounded,
          activeIcon: Icons.receipt_long_rounded,
          label: l10n.myOrders,
        ),
        _NavItemData(
          icon: Icons.account_balance_wallet_rounded,
          activeIcon: Icons.account_balance_wallet_rounded,
          label: l10n.finance,
        ),
        _NavItemData(
          icon: Icons.person_rounded,
          activeIcon: Icons.person_rounded,
          label: l10n.profile,
        ),
      ];
    }
    if (_isGuest) {
      return [
        _NavItemData(
          icon: Icons.home_rounded,
          activeIcon: Icons.home_rounded,
          label: l10n.home,
        ),
        _NavItemData(
          icon: Icons.search_rounded,
          activeIcon: Icons.search_rounded,
          label: l10n.search,
        ),
        _NavItemData(
          icon: Icons.person_rounded,
          activeIcon: Icons.person_rounded,
          label: l10n.profile,
        ),
      ];
    }
    return [
      _NavItemData(
        icon: Icons.home_rounded,
        activeIcon: Icons.home_rounded,
        label: l10n.home,
      ),
      _NavItemData(
        icon: Icons.search_rounded,
        activeIcon: Icons.search_rounded,
        label: l10n.search,
      ),
      _NavItemData(
        icon: Icons.biotech_rounded,
        activeIcon: Icons.biotech_rounded,
        label: l10n.results,
      ),
      _NavItemData(
        icon: Icons.person_rounded,
        activeIcon: Icons.person_rounded,
        label: l10n.profile,
      ),
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screens = _getScreens();
    final navItems = _getNavItems(l10n);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          boxShadow: [
            BoxShadow(
              color: AppTheme.gray900.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                navItems.length,
                (index) => _buildNavItem(
                  icon: navItems[index].icon,
                  activeIcon: navItems[index].activeIcon,
                  label: navItems[index].label,
                  index: index,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppTheme.primaryColor : AppTheme.gray400,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color:
                          isActive ? AppTheme.primaryColor : AppTheme.gray400,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// Home Tab Screen - A wrapper for the existing HomeScreen
class HomeTabScreen extends StatelessWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
