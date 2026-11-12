import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/order_service.dart';
import '../order/order_details_screen.dart';
import '../../../l10n/app_localizations.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  List<Order> _orders = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedStatus = 'all';
            break;
          case 1:
            _selectedStatus = 'in_progress';
            break;
          case 2:
            _selectedStatus = 'completed';
            break;
        }
      });
      _loadOrders();
    });
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    final result = await OrderService.getPatientOrders(
      status: _selectedStatus == 'all' || _selectedStatus == 'in_progress'
          ? null
          : _selectedStatus,
    );

    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          var loaded = List<Order>.from(result['orders'] ?? []);
          if (_selectedStatus == 'in_progress') {
            loaded = loaded
                .where((order) => order.status != 'completed' && order.status != 'cancelled')
                .toList();
          }
          _orders = loaded;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
            final query = _searchQuery.trim().toLowerCase();
    Order? liveOrder;
    Order? quotedOrder; // order awaiting user price approval
    for (final order in _orders) {
      if (quotedOrder == null && order.status == 'quoted') {
        quotedOrder = order;
      }
      if (liveOrder == null &&
          (order.status == 'nurse_assigned' ||
              order.status == 'at_patient' ||
              order.status == 'going_to_lab')) {
        liveOrder = order;
      }
      if (liveOrder != null && quotedOrder != null) break;
    }
    final visibleOrders = query.isEmpty
        ? _orders
        : _orders.where((order) {
            final labName = (order.labData?['name'] ?? '').toString().toLowerCase();
            return order.qrCode.toLowerCase().contains(query) || labName.contains(query);
          }).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LABGO CARE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.myOrders,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.gray900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.06),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          _showSearch = !_showSearch;
                          if (!_showSearch) {
                            _searchController.clear();
                            _searchQuery = '';
                          }
                        });
                      },
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.search_rounded, color: AppTheme.primaryDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.searchOrders,
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.gray400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _filterPill(l10n.all, 0),
                  const SizedBox(width: 8),
                  _filterPill(l10n.inProgress, 1),
                  const SizedBox(width: 8),
                  _filterPill(l10n.completed, 2),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      color: AppTheme.primaryColor,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        children: [
                          if (quotedOrder != null) ...[
                            _PriceApprovalBanner(
                              order: quotedOrder,
                              onTap: () => _openOrder(quotedOrder!),
                              l10n: l10n,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (liveOrder != null) ...[
                            _LiveTrackingBanner(
                              order: liveOrder,
                              onTap: () => _openOrder(liveOrder!),
                            ),
                            const SizedBox(height: 20),
                          ],
                          Text(
                            l10n.allOrders,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.gray900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (visibleOrders.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 48),
                              child: _buildEmptyState(l10n),
                            )
                          else
                            ...visibleOrders.map(
                              (order) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _OrderCard(
                                  order: order,
                                  onTap: () => _openOrder(order),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterPill(String label, int index) {
    final selected = _tabController.index == index;
    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppTheme.gray700,
          ),
        ),
      ),
    );
  }

  Future<void> _openOrder(Order order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrderDetailsScreen(order: order)),
    );
    _loadOrders();
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
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
          const SizedBox(height: 24),
          Text(
            l10n.noOrdersFound,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noOrdersSubtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveTrackingBanner extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _LiveTrackingBanner({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: const Color(0xFFEAE7FB),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.trackYourOrderLive,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.technicianOnTheWay,
                      style: const TextStyle(fontSize: 12, color: AppTheme.gray600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner shown when an order is waiting for the user to approve a price quote
// ─────────────────────────────────────────────────────────────────────────────
class _PriceApprovalBanner extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  const _PriceApprovalBanner({
    required this.order,
    required this.onTap,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);
    const amberDark = Color(0xFFD97706);
    const amberBg = Color(0xFFFFFBEB);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: amberBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: amber.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: amber.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              // Pulsing bell icon in amber circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: amber,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.priceQuoteReceived,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.tapToReviewAndApprovePrice,
                      style: const TextStyle(
                        fontSize: 12,
                        color: amberDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: amber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Review',
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

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _getStatusColor(order.status);
    final labName = order.labData?['name']?.toString() ?? l10n.orders;
    final dateText = DateFormat('d MMMM yyyy', Localizations.localeOf(context).toString())
        .format(order.createdAt.toLocal());

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE7FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.description_outlined, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${order.qrCode} • $dateText',
                      style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusDisplayName(order.status, l10n),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.gray400),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'quoted':
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

  String _getStatusDisplayName(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.pending;
      case 'quoted':
        return l10n.priceQuoteReceived;
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
