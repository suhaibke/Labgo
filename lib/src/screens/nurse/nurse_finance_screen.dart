import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../services/nurse_finance_service.dart';
import '../../services/nurse_orders_service.dart';
import 'nurse_order_details_screen.dart';

/// Nurse finance screen showing balance, earnings, and transactions
class NurseFinanceScreen extends StatefulWidget {
  const NurseFinanceScreen({super.key});

  @override
  State<NurseFinanceScreen> createState() => _NurseFinanceScreenState();
}

class _NurseFinanceScreenState extends State<NurseFinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  NurseFinanceOverview? _overview;
  List<NurseTransaction> _transactions = [];
  List<PendingAdminSettlement> _pendingAdminSettlements = [];

  // Month filter state
  List<Map<String, dynamic>> _availableMonths = [];
  int? _selectedYear;
  int? _selectedMonth;
  Map<String, dynamic>? _monthlyStats;
  List<NurseTransaction> _monthlyTransactions = [];

  bool _isLoading = true;
  bool _isLoadingTransactions = false;
  bool _isLoadingSettlements = false;
  bool _isLoadingMonthly = false;

  final currencyFormat = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _loadTabData();
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadOverview(),
      _loadAvailableMonths(),
    ]);
  }

  Future<void> _loadAllData() async {
    await _loadOverview();
    _loadPendingAdminSettlements();
    _loadTransactions();
  }

  Future<void> _loadAvailableMonths() async {
    final result = await NurseFinanceService.getAvailableMonths();
    if (mounted && result['success'] == true) {
      setState(() {
        _availableMonths =
            List<Map<String, dynamic>>.from(result['months'] ?? []);
        // Set current month as default if available
        final now = DateTime.now();
        final currentMonthExists = _availableMonths.any(
          (m) => m['year'] == now.year && m['month'] == now.month,
        );
        if (currentMonthExists) {
          _selectedYear = now.year;
          _selectedMonth = now.month;
        } else if (_availableMonths.isNotEmpty) {
          _selectedYear = _availableMonths.first['year'];
          _selectedMonth = _availableMonths.first['month'];
        }
      });
      // Load monthly data for selected month
      if (_selectedYear != null && _selectedMonth != null) {
        _loadMonthlyData();
      }
    }
  }

  Future<void> _loadMonthlyData() async {
    if (_selectedYear == null || _selectedMonth == null) return;

    setState(() => _isLoadingMonthly = true);

    final result = await NurseFinanceService.getMonthlyData(
      _selectedYear!,
      _selectedMonth!,
    );

    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _monthlyStats = result['stats'] as Map<String, dynamic>?;
          _monthlyTransactions = List<NurseTransaction>.from(
            result['transactions'] ?? [],
          );
        }
        _isLoadingMonthly = false;
      });
    }
  }

  Future<void> _loadOverview() async {
    setState(() => _isLoading = true);

    final result = await NurseFinanceService.getFinanceOverview();

    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _overview = result['overview'] as NurseFinanceOverview;
        }
        _isLoading = false;
      });

      // Load initial tab data
      _loadTabData();
    }
  }

  Future<void> _loadTabData() async {
    switch (_tabController.index) {
      case 1: // Transactions tab
        if (_transactions.isEmpty) {
          _loadTransactions();
        }
        break;
      case 2: // Pending admin settlements tab
        if (_pendingAdminSettlements.isEmpty) {
          _loadPendingAdminSettlements();
        }
        break;
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoadingTransactions = true);

    final result = await NurseFinanceService.getTransactions();

    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _transactions =
              List<NurseTransaction>.from(result['transactions'] ?? []);
        }
        _isLoadingTransactions = false;
      });
    }
  }

  Future<void> _loadPendingAdminSettlements() async {
    setState(() => _isLoadingSettlements = true);

    final result = await NurseFinanceService.getPendingAdminSettlements();

    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _pendingAdminSettlements =
              List<PendingAdminSettlement>.from(result['settlements'] ?? []);
        }
        _isLoadingSettlements = false;
      });
    }
  }

  String _getMonthName(int month, AppLocalizations l10n) {
    switch (month) {
      case 1:
        return l10n.january;
      case 2:
        return l10n.february;
      case 3:
        return l10n.march;
      case 4:
        return l10n.april;
      case 5:
        return l10n.may;
      case 6:
        return l10n.june;
      case 7:
        return l10n.july;
      case 8:
        return l10n.august;
      case 9:
        return l10n.september;
      case 10:
        return l10n.october;
      case 11:
        return l10n.november;
      case 12:
        return l10n.december;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      appBar: AppBar(
        title: Image.asset(
          'assets/images/logo.png',
          height: 36,
          fit: BoxFit.contain,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTheme.gray700),
            onPressed: () {
              _loadOverview();
              _loadAvailableMonths();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.gray500,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          tabs: [
            Tab(text: l10n.financeOverview),
            Tab(text: l10n.transactions),
            Tab(text: l10n.pendingSettlements),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildTransactionsTab(),
                _buildPendingSettlementsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final l10n = AppLocalizations.of(context)!;
    if (_overview == null) {
      return Center(child: Text(l10n.failedToLoadFinanceOverview));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadOverview();
        await _loadAvailableMonths();
        if (_selectedYear != null && _selectedMonth != null) {
          await _loadMonthlyData();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
            _buildBalanceCard(),
            const SizedBox(height: 16),

            // Stats Grid
            _buildStatsGrid(),
            const SizedBox(height: 24),

            // Month Selector
            _buildMonthSelector(),
            const SizedBox(height: 16),

            // Monthly Summary
            _buildMonthlySummary(),
            const SizedBox(height: 24),

            // Pending Admin Settlements Alert
            _buildPendingAlert(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final l10n = AppLocalizations.of(context)!;

    if (_availableMonths.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _availableMonths.length,
        itemBuilder: (context, index) {
          final monthData = _availableMonths[index];
          final year = monthData['year'] as int;
          final month = monthData['month'] as int;
          final isSelected = _selectedYear == year && _selectedMonth == month;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedYear = year;
                  _selectedMonth = month;
                });
                _loadMonthlyData();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${_getMonthName(month, l10n)} $year',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.gray600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthlySummary() {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoadingMonthly) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_monthlyStats == null || _selectedMonth == null) {
      return const SizedBox.shrink();
    }

    final orderCount = _monthlyStats!['orderCount'] ?? 0;
    final nurseEarning = (_monthlyStats!['nurseNetEarning'] ?? 0).toDouble();
    final adminAmount = (_monthlyStats!['adminAmount'] ?? 0).toDouble();
    final totalAmount = (_monthlyStats!['totalCollected'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_getMonthName(_selectedMonth!, l10n)} $_selectedYear',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildMonthlyStat(
                  l10n.completedOrders,
                  orderCount.toString(),
                  Icons.assignment_turned_in_rounded,
                  AppTheme.primaryColor,
                ),
              ),
              Container(
                height: 50,
                width: 1,
                color: AppTheme.gray200,
              ),
              Expanded(
                child: _buildMonthlyStat(
                  l10n.monthlyEarnings,
                  '${currencyFormat.format(nurseEarning)}',
                  Icons.trending_up_rounded,
                  AppTheme.success,
                ),
              ),
            ],
          ),

          const Divider(height: 32),

          // Breakdown
          _buildBreakdownRow(
              l10n.totalCollected, totalAmount, AppTheme.gray700),
          const SizedBox(height: 8),
          _buildBreakdownRow(l10n.adminShare, adminAmount, AppTheme.error),
          const SizedBox(height: 8),
          _buildBreakdownRow(
              l10n.totalEarnings, nurseEarning, AppTheme.success),

          // Monthly Transactions Preview
          if (_monthlyTransactions.isNotEmpty) ...[
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.transactions,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                  ),
                ),
                TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: Text(
                    l10n.viewAll,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...(_monthlyTransactions.take(3).map(
                  (t) => _buildMiniTransactionCard(t),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyStat(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.gray500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.gray600,
          ),
        ),
        Text(
          '${currencyFormat.format(amount)} IQD',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniTransactionCard(NurseTransaction transaction) {
    final isPositive = transaction.type == 'commission_earned';

    return GestureDetector(
      onTap: () {
        if (transaction.orderId.isNotEmpty) {
          _showOrderDetails(transaction.orderId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.gray50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isPositive
                    ? AppTheme.success.withOpacity(0.1)
                    : AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPositive
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: isPositive ? AppTheme.success : AppTheme.error,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                transaction.typeDisplayName,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.gray800,
                ),
              ),
            ),
            Text(
              '${isPositive ? '+' : '-'}${currencyFormat.format(transaction.amount)}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPositive ? AppTheme.success : AppTheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final l10n = AppLocalizations.of(context)!;

    // Use monthly earnings when a month is selected, otherwise use all-time total
    final double displayEarnings = _monthlyStats != null
        ? (_monthlyStats!['nurseNetEarning'] ?? 0).toDouble()
        : _overview!.totalEarnings;

    // Label changes based on whether monthly data is shown
    final String earningsLabel = _monthlyStats != null && _selectedMonth != null
        ? l10n.monthlyEarnings
        : l10n.totalEarnings;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  earningsLabel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'IQD',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(displayEarnings),
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${l10n.currentBalance}: ',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${currencyFormat.format(_overview!.currentBalance)} IQD',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final l10n = AppLocalizations.of(context)!;

    // Use monthly data when a month is selected, otherwise use all-time overview
    final double monthlyEarnings = _monthlyStats != null
        ? (_monthlyStats!['nurseNetEarning'] ?? 0).toDouble()
        : _overview!.totalEarnings;
    final double monthlyPaidToAdmin = _monthlyStats != null
        ? (_monthlyStats!['adminAmount'] ?? 0).toDouble()
        : _overview!.totalPaidToAdmin;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            l10n.totalEarnings,
            currencyFormat.format(monthlyEarnings),
            Icons.trending_up_rounded,
            AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            l10n.paidToAdmin,
            currencyFormat.format(monthlyPaidToAdmin),
            Icons.account_balance_rounded,
            AppTheme.info,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.gray500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value IQD',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAlert() {
    final l10n = AppLocalizations.of(context)!;
    if (_overview!.pendingAdminPayments <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_overview!.pendingAdminPayments} ${l10n.pendingSettlements}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.adminShare}: ${currencyFormat.format(_overview!.pendingAdminAmount)} IQD',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.gray600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _tabController.animateTo(2),
            child: Text(
              l10n.viewAll,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoadingTransactions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 64, color: AppTheme.gray300),
            const SizedBox(height: 16),
            Text(
              l10n.noTransactions,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.gray500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _buildTransactionCard(_transactions[index]),
      ),
    );
  }

  Widget _buildTransactionCard(NurseTransaction transaction) {
    final l10n = AppLocalizations.of(context)!;
    final isPositive = transaction.type == 'commission_earned';

    return GestureDetector(
      onTap: () {
        if (transaction.orderId.isNotEmpty) {
          _showOrderDetails(transaction.orderId);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isPositive
                    ? AppTheme.success.withOpacity(0.1)
                    : AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPositive
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: isPositive ? AppTheme.success : AppTheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.typeDisplayName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat.yMd().add_jm().format(transaction.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isPositive ? '+' : '-'}${currencyFormat.format(transaction.amount)} IQD',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isPositive ? AppTheme.success : AppTheme.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.balance}: ${currencyFormat.format(transaction.balanceAfter)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.gray500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSettlementsTab() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoadingSettlements) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingAdminSettlements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 64, color: AppTheme.success),
            const SizedBox(height: 16),
            Text(
              l10n.noPendingSettlements,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noPendingSettlementsSubtitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.gray500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingAdminSettlements,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingAdminSettlements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _buildPendingAdminSettlementCard(_pendingAdminSettlements[index]),
      ),
    );
  }

  Widget _buildPendingAdminSettlementCard(PendingAdminSettlement settlement) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => _showOrderDetails(settlement.orderId),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settlement.labName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gray900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.orderText} #${settlement.orderNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.pending,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildFinancialRow(
                    l10n.orderTotal,
                    '${currencyFormat.format(settlement.totalAmount)} IQD',
                    AppTheme.gray700,
                  ),
                ),
                Expanded(
                  child: _buildFinancialRow(
                    l10n.adminShare,
                    '${currencyFormat.format(settlement.adminAmount)} IQD',
                    AppTheme.error,
                    isBold: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.gray50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: AppTheme.gray500),
                  const SizedBox(width: 6),
                  Text(
                    '${l10n.commissionRate}: ${settlement.nurseCommissionRate.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.gray600,
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

  Widget _buildFinancialRow(String label, String value, Color color,
      {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.gray500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showOrderDetails(String orderId) async {
    final l10n = AppLocalizations.of(context)!;
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Fetch order details
    final result = await NurseOrdersService.getNurseOrderDetails(orderId);

    // Hide loading
    if (mounted) Navigator.pop(context);

    if (result['success'] == true && result['order'] != null) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NurseOrderDetailsScreen(
              order: result['order'],
              onRefresh: _loadAllData,
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? l10n.failedToLoadOrderDetails),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
