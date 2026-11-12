import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../order/location_selection_screen.dart';
import '../home/home_screen.dart';
import '../search/search_screen.dart';
import '../order/orders_screen.dart';
import '../test_results/test_results_screen.dart';
import '../profile/profile_screen.dart';
import '../nurse/nurse_available_orders_screen.dart';
import '../nurse/nurse_my_orders_screen.dart';
import '../nurse/nurse_finance_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_bottom_nav_bar.dart';

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
    final remote = await AuthService().refreshUserData();
    final userData = remote ?? await AuthService().getUserData();
    final viewMode = await AuthService.getViewMode();
    if (userData != null && mounted) {
      setState(() {
        _userRole = userData['role'];
        _viewMode = viewMode;
      });
    }

    // Technicians need a base location on file so the admin dashboard can
    // rank them by distance when assigning new orders. Only enforce it while
    // actually in nurse view; the patient interface must never ask for
    // location at startup (it is requested at order time instead).
    if (userData?['role'] == 'nurse' && viewMode != 'patient') {
      final coordinates = userData?['defaultLocation']?['coordinates'];
      final hasLocation = coordinates?['latitude'] != null;
      if (!hasLocation && mounted) {
        await _requireNurseLocation();
      }
    }
  }

  Future<void> _requireNurseLocation() async {
    // Keep asking until the location is actually persisted on the server,
    // otherwise a silently failed save causes the prompt to reappear on
    // every launch with the previous input lost.
    OrderLocation? draft;
    while (mounted) {
      final result = await Navigator.of(context).push<OrderLocation>(
        MaterialPageRoute(
          builder: (context) => LocationSelectionScreen(
            mandatory: true,
            initialLocation: draft,
          ),
          fullscreenDialog: true,
        ),
      );
      if (result == null || !mounted) return;

      final response = await AuthService.updateProfile(
        latitude: result.latitude,
        longitude: result.longitude,
        address: result.address,
        landmark: result.landmark,
      );
      if (response['success'] == true) return;

      draft = result;
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToUpdateProfile)),
        );
      }
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
      OrdersScreen(),
      TestResultsScreen(),
      ProfileScreen(),
    ];
  }

  List<NavBarItemData> _getNavItems(AppLocalizations l10n) {
    if (_effectiveRole == 'nurse') {
      return [
        NavBarItemData(icon: Icons.assignment_rounded, label: l10n.availableOrders),
        NavBarItemData(icon: Icons.receipt_long_rounded, label: l10n.myOrders),
        NavBarItemData(icon: Icons.account_balance_wallet_rounded, label: l10n.finance),
        NavBarItemData(icon: Icons.person_rounded, label: l10n.profile),
      ];
    }
    if (_isGuest) {
      return [
        NavBarItemData(icon: Icons.home_rounded, label: l10n.home),
        NavBarItemData(icon: Icons.search_rounded, label: l10n.search),
        NavBarItemData(icon: Icons.person_rounded, label: l10n.profile),
      ];
    }
    return [
      NavBarItemData(icon: TablerIcons.home, label: l10n.home),
      NavBarItemData(icon: TablerIcons.clipboard_list, label: l10n.myOrders),
      NavBarItemData(icon: TablerIcons.file_description, label: l10n.results),
      NavBarItemData(icon: TablerIcons.user_circle, label: l10n.profile),
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
    // Only regular patients get the floating "new request" add button.
    final showAddButton = !_isGuest && _effectiveRole != 'nurse';

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        // Pause animations/timers on hidden tabs (keeps home promo from janking others)
        children: [
          for (int i = 0; i < screens.length; i++)
            TickerMode(
              enabled: i == _currentIndex,
              child: screens[i],
            ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        items: navItems,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        addButtonAfterIndex: 1,
        onAddTap: showAddButton
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchScreen()),
                );
              }
            : null,
      ),
    );
  }
}

// Home Tab Screen - A wrapper for the existing HomeScreen
class HomeTabScreen extends StatelessWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
