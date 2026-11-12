import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/nurse_orders_service.dart';
import '../../services/order_service.dart';
import 'nurse_order_details_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Nurse home screen showing available confirmed orders
/// Optimized with client-side filtering for instant tab switches
class NurseHomeScreen extends StatefulWidget {
  const NurseHomeScreen({super.key});

  @override
  State<NurseHomeScreen> createState() => _NurseHomeScreenState();
}

class _NurseHomeScreenState extends State<NurseHomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _mainTabController;
  late TabController _myOrdersTabController;

  // Data storage - load once, filter client-side
  List<Order> _availableOrders = [];
  List<Order> _myOrders = [];
  bool _isLoading = true;
  String _myOrdersStatusFilter = 'in_progress';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _myOrdersTabController = TabController(length: 3, vsync: this);

    // Only listen to main tab changes - sub-tabs filter client-side
    _mainTabController.addListener(() {
      if (_mainTabController.indexIsChanging) return;
      if (mounted) {
        _loadCurrentTabData();
      }
    });

    _loadCurrentTabData();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _myOrdersTabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentTabData() async {
    setState(() => _isLoading = true);

    if (_mainTabController.index == 0) {
      // Load available orders
      final result = await NurseOrdersService.getAvailableOrders();
      if (mounted && result['success'] == true) {
        setState(() {
          _availableOrders = List<Order>.from(result['orders'] ?? []);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } else {
      // Load ALL my orders once (filter client-side)
      final result = await NurseOrdersService.getMyOrders();
      if (mounted && result['success'] == true) {
        setState(() {
          _myOrders = List<Order>.from(result['orders'] ?? []);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Client-side filtering - instant like test results screen
  List<Order> get _displayedOrders {
    if (_mainTabController.index == 0) {
      return _availableOrders;
    }

    // Filter my orders client-side based on selected filter
    return _myOrders.where((order) {
      switch (_myOrdersStatusFilter) {
        case 'in_progress':
          return order.status == 'nurse_assigned' ||
              order.status == 'at_patient' ||
              order.status == 'going_to_lab' ||
              order.status == 'at_lab' ||
              order.status == 'in_progress';
        case 'completed':
          return order.status == 'completed';
        case 'cancelled':
          return order.status == 'cancelled';
        default:
          return true;
      }
    }).toList();
  }

  void _updateMyOrdersFilter(int tabIndex) {
    final newFilter = switch (tabIndex) {
      0 => 'in_progress',
      1 => 'completed',
      2 => 'cancelled',
      _ => 'in_progress',
    };

    if (_myOrdersStatusFilter != newFilter) {
      setState(() => _myOrdersStatusFilter = newFilter);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'confirmed':
        return AppTheme.info;
      case 'nurse_assigned':
      case 'at_patient':
      case 'going_to_lab':
      case 'at_lab':
      case 'in_progress':
        return AppTheme.primaryColor;
      case 'completed':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.gray500;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'confirmed':
        return Icons.check_circle_outline_rounded;
      case 'nurse_assigned':
        return Icons.person_search_rounded;
      case 'at_patient':
        return Icons.location_on_rounded;
      case 'going_to_lab':
        return Icons.directions_car_rounded;
      case 'at_lab':
        return Icons.biotech_rounded;
      case 'in_progress':
        return Icons.science_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return 'Just now';
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Image.asset(
          'assets/images/logo.png',
          height: 36,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Main menu bar - Available Orders / My Orders
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildMainTab(
                    l10n.availableOrders,
                    _mainTabController.index == 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMainTab(
                    l10n.myOrders,
                    _mainTabController.index == 1,
                  ),
                ),
              ],
            ),
          ),

          // Show filter tabs for My Orders
          if (_mainTabController.index == 1)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterTab(
                      l10n.inProgress,
                      _myOrdersTabController.index == 0,
                      AppTheme.info,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterTab(
                      l10n.completed,
                      _myOrdersTabController.index == 1,
                      AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterTab(
                      l10n.cancelled,
                      _myOrdersTabController.index == 2,
                      AppTheme.error,
                    ),
                  ),
                ],
              ),
            ),
          // Orders list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  )
                : _displayedOrders.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadCurrentTabData,
                        color: AppTheme.primaryColor,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildEmptyState(l10n),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCurrentTabData,
                        color: AppTheme.primaryColor,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          itemCount: _displayedOrders.length,
                          cacheExtent: 500, // Pre-render items for smooth scrolling
                          addAutomaticKeepAlives: true, // Keep widget state
                          addRepaintBoundaries: true, // Add repaint boundaries
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return RepaintBoundary(
                              child: _OrderCard(
                                key: ValueKey(_displayedOrders[index].id),
                                order: _displayedOrders[index],
                                onTap: () async {
                                  final shouldRefresh = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NurseOrderDetailsScreen(
                                        order: _displayedOrders[index],
                                        onRefresh: _loadCurrentTabData,
                                      ),
                                    ),
                                  );
                                  // Only reload if explicitly requested
                                  if (shouldRefresh == true) {
                                    _loadCurrentTabData();
                                  }
                                },
                                getStatusColor: _getStatusColor,
                                getStatusIcon: _getStatusIcon,
                                formatDate: _formatDate,
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    final isEmptyAvailable = _mainTabController.index == 0;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.gray100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEmptyAvailable
                  ? Icons.assignment_rounded
                  : Icons.receipt_long_rounded,
              size: 40,
              color: AppTheme.gray400,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isEmptyAvailable ? l10n.noAvailableOrders : l10n.noOrdersFound,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEmptyAvailable
                ? l10n.noAvailableOrdersSubtitle
                : l10n.noOrdersSubtitle,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppTheme.gray500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, bool isSelected, Color color) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () {
        if (label == l10n.inProgress) {
          _myOrdersTabController.animateTo(0);
          _updateMyOrdersFilter(0);
        } else if (label == l10n.completed) {
          _myOrdersTabController.animateTo(1);
          _updateMyOrdersFilter(1);
        } else if (label == l10n.cancelled) {
          _myOrdersTabController.animateTo(2);
          _updateMyOrdersFilter(2);
        }
      },
      child: Container(
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : AppTheme.gray50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.gray600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildMainTab(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        final index = label == AppLocalizations.of(context)!.availableOrders ? 0 : 1;
        _mainTabController.animateTo(index);
      },
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.gray50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.gray700,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  final Color Function(String) getStatusColor;
  final IconData Function(String) getStatusIcon;
  final String Function(DateTime) formatDate;

  const _OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.getStatusColor,
    required this.getStatusIcon,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = getStatusColor(order.status);
    final statusIcon = getStatusIcon(order.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.gray200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status badge and QR Code
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getStatusDisplayName(order.status, l10n),
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '#${order.qrCode}',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Tests count and date
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order.tests.length} ${l10n.tests}',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: AppTheme.gray600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatDate(order.createdAt),
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: AppTheme.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${order.formattedTotalPrice} IQD',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),

              // Location preview
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: AppTheme.gray500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.location.address,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppTheme.gray600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusDisplayName(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.pending;
      case 'confirmed':
        return l10n.confirmed;
      case 'nurse_assigned':
        return l10n.nurseAssigned;
      case 'sample_collected':
        return l10n.sampleCollected;
      case 'at_lab':
        return l10n.atLab;
      case 'completed':
        return l10n.completed;
      case 'cancelled':
        return l10n.cancelled;
      default:
        return status;
    }
  }
}
