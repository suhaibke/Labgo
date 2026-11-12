import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/nurse_orders_service.dart';
import '../../services/order_service.dart';
import 'nurse_order_details_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Nurse my orders screen - shows orders assigned to the nurse
/// Uses client-side filtering for instant tab switches
class NurseMyOrdersScreen extends StatefulWidget {
  const NurseMyOrdersScreen({super.key});

  @override
  State<NurseMyOrdersScreen> createState() => _NurseMyOrdersScreenState();
}

class _NurseMyOrdersScreenState extends State<NurseMyOrdersScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _filterTabController;
  List<Order> _myOrders = [];
  bool _isLoading = true;
  String _statusFilter = 'in_progress';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _filterTabController = TabController(length: 3, vsync: this);
    _filterTabController.addListener(_onFilterTabChanged);
    _loadMyOrders();
  }

  @override
  void dispose() {
    _filterTabController.removeListener(_onFilterTabChanged);
    _filterTabController.dispose();
    super.dispose();
  }

  void _onFilterTabChanged() {
    if (_filterTabController.indexIsChanging) return;
    if (mounted) {
      _updateMyOrdersFilter(_filterTabController.index);
    }
  }

  Future<void> _loadMyOrders() async {
    setState(() => _isLoading = true);

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

  // Client-side filtering - instant like test results screen
  List<Order> get _displayedOrders {
    return _myOrders.where((order) {
      switch (_statusFilter) {
        case 'in_progress':
          return order.status == 'nurse_assigned' ||
              order.status == 'sample_collected';
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

    if (_statusFilter != newFilter) {
      setState(() => _statusFilter = newFilter);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'confirmed':
        return AppTheme.info;
      case 'nurse_assigned':
        return AppTheme.primaryColor;
      case 'sample_collected':
        return Colors.orange;
      case 'at_lab':
        return Colors.cyan;
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
      case 'sample_collected':
        return Icons.bloodtype_rounded;
      case 'at_lab':
        return Icons.biotech_rounded;
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
          // Filter tabs - In Progress, Completed, Cancelled
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterTab(
                    l10n.inProgress,
                    _filterTabController.index == 0,
                    AppTheme.info,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterTab(
                    l10n.completed,
                    _filterTabController.index == 1,
                    AppTheme.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterTab(
                    l10n.cancelled,
                    _filterTabController.index == 2,
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
                        onRefresh: _loadMyOrders,
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
                        onRefresh: _loadMyOrders,
                        color: AppTheme.primaryColor,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          itemCount: _displayedOrders.length,
                          cacheExtent: 500,
                          addAutomaticKeepAlives: true,
                          addRepaintBoundaries: true,
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
                                        onRefresh: _loadMyOrders,
                                      ),
                                    ),
                                  );
                                  if (shouldRefresh == true) {
                                    _loadMyOrders();
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
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 40,
              color: AppTheme.gray400,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noOrdersFound,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noOrdersSubtitle,
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
    return GestureDetector(
      onTap: () {
        if (label == AppLocalizations.of(context)!.inProgress) {
          _filterTabController.animateTo(0);
          _updateMyOrdersFilter(0);
        } else if (label == AppLocalizations.of(context)!.completed) {
          _filterTabController.animateTo(1);
          _updateMyOrdersFilter(1);
        } else if (label == AppLocalizations.of(context)!.cancelled) {
          _filterTabController.animateTo(2);
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
                  if (order.status == 'sample_collected' ||
                      order.status == 'at_lab' ||
                      order.status == 'completed')
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
