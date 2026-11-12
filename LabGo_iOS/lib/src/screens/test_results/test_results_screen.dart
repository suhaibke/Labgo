import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/order_service.dart';
import '../../../l10n/app_localizations.dart';
import '../order/order_details_screen.dart';

class TestResultsScreen extends StatefulWidget {
  const TestResultsScreen({super.key});

  @override
  State<TestResultsScreen> createState() => _TestResultsScreenState();
}

class _TestResultsScreenState extends State<TestResultsScreen> {
  List<Order> _orders = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    final result = await OrderService.getPatientOrders();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _orders = result['orders'] as List<Order>;
        }
      });
    }
  }

  List<Order> get _filteredOrders {
    switch (_selectedFilter) {
      case 'pending':
        return _orders.where((o) => o.isPending).toList();
      case 'confirmed':
        return _orders.where((o) => o.isConfirmedStatus || o.isNurseAssigned || o.isSampleCollected || o.isAtLab).toList();
      case 'completed':
        return _orders.where((o) => o.isCompleted).toList();
      default:
        return _orders;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF4A900);
      case 'confirmed':
      case 'nurse_assigned':
        return const Color(0xFF4A90E2);
      case 'sample_collected':
        return Colors.orange;
      case 'at_lab':
        return Colors.cyan;
      case 'completed':
        return const Color(0xFF00BFA5);
      case 'cancelled':
        return const Color(0xFFE53935);
      default:
        return AppTheme.gray400;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.access_time_rounded;
      case 'confirmed':
        return Icons.check_circle_outline_rounded;
      case 'nurse_assigned':
        return Icons.person_outline_rounded;
      case 'sample_collected':
        return Icons.bloodtype_rounded;
      case 'at_lab':
        return Icons.science_outlined;
      case 'completed':
        return Icons.task_alt_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getStatusText(String status, AppLocalizations l10n) {
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

  void _navigateToDetails(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(order: order),
      ),
    ).then((_) => _loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            _buildAppBar(context, l10n),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : Column(
                      children: [
                        // Filter Tabs - always visible when not loading
                        _buildFilterTabs(l10n),
                        // Orders List or Empty State
                        Expanded(
                          child: _filteredOrders.isEmpty
                              ? _buildEmptyState(l10n)
                              : _buildOrdersList(l10n),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Padding(padding: EdgeInsets.fromLTRB(0, 0, 30, 0)),
          const Spacer(),

          // Logo (Centered)
          Image.asset(
            'assets/images/logo.png',
            height: 56,
            fit: BoxFit.contain,
          ),

          const Spacer(),
          
          // Order Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_orders.length}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                    fontSize: 13,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppTheme.primaryColor,
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.loadingOrders,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.gray500,
              fontWeight: FontWeight.w500,
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.gray100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.science_outlined,
              size: 36,
              color: AppTheme.gray400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.noOrdersYet,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.startByOrderingLabTests,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.gray500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(AppLocalizations l10n) {
    // Get localized filter labels
    final allLabel = l10n.all;
    final pendingLabel = l10n.pending;
    final activeLabel = l10n.active;
    final completedLabel = l10n.completed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterTab(allLabel, _selectedFilter == 'all'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterTab(pendingLabel, _selectedFilter == 'pending'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterTab(activeLabel, _selectedFilter == 'confirmed'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterTab(completedLabel, _selectedFilter == 'completed'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(AppLocalizations l10n) {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppTheme.primaryColor,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: _filteredOrders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = _filteredOrders[index];
          return _OrderCard(
            order: order,
            statusColor: _getStatusColor(order.status),
            statusIcon: _getStatusIcon(order.status),
            statusText: _getStatusText(order.status, l10n),
            l10n: l10n,
            onTap: () => _navigateToDetails(order),
          );
        },
      ),
    );
  }

  Widget _buildFilterTab(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() {
        // Map label to filter value using the actual label text
        final labelLower = label.toLowerCase();
        if (labelLower == 'active' || labelLower == 'نشط' || labelLower == 'چالاکی' || labelLower == 'aktif') {
          _selectedFilter = 'confirmed';
        } else if (labelLower == 'completed' || labelLower == 'done' || labelLower == 'مكتمل' || labelLower == 'تەواو' || labelLower == 'tamamlandı') {
          _selectedFilter = 'completed';
        } else if (labelLower == 'pending' || labelLower == 'قيد الانتظار' || labelLower == 'معلق' || labelLower == 'چاوەروە' || labelLower == 'beklemede') {
          _selectedFilter = 'pending';
        } else {
          _selectedFilter = 'all';
        }
      }),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.gray50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
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
  final Color statusColor;
  final IconData statusIcon;
  final String statusText;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.statusIcon,
    required this.statusText,
    required this.l10n,
    required this.onTap,
  });

  String _formatDate(DateTime date) {
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

  String _formatPrice(int price) {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return price.toString().replaceAllMapped(formatter, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Status Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Order Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.qrCode}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.gray900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.tests.length} ${order.tests.length == 1 ? l10n.test : l10n.tests}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.gray500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Date Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.gray50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDate(order.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.gray600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Test Names - Full Width
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.gray50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    order.tests.map((t) => t.testName).take(2).join(' • '),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.gray700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (order.tests.length > 2) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.more(order.tests.length - 2),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.gray500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

                const SizedBox(height: 12),

                // Footer Row
                Row(
                  children: [
                    // Status Badge
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
                            size: 12,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Price
                    Text(
                      '${_formatPrice(order.totalPrice)} IQD',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppTheme.gray300,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
