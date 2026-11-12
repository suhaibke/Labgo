import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/result_file.dart';
import 'result_detail_screen.dart';

class TestResultsScreen extends StatefulWidget {
  final String? focusOrderId;

  const TestResultsScreen({super.key, this.focusOrderId});

  @override
  State<TestResultsScreen> createState() => _TestResultsScreenState();
}

class _TestResultsScreenState extends State<TestResultsScreen> {
  List<Order> _results = [];
  bool _isLoading = true;
  bool _didOpenFocus = false;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    final result = await OrderService.getPatientOrders(limit: 100);
    if (!mounted) return;
    final orders = result['success'] == true
        ? List<Order>.from(result['orders'] as List<Order>)
        : <Order>[];
    setState(() {
      _results = orders.where((o) => o.hasSentResult).toList();
      _isLoading = false;
    });
    _openFocusedIfNeeded();
  }

  void _openFocusedIfNeeded() {
    if (_didOpenFocus || widget.focusOrderId == null) return;
    final matches = _results.where((o) => o.id == widget.focusOrderId);
    if (matches.isEmpty) return;
    final match = matches.first;
    _didOpenFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openResult(match);
    });
  }

  void _openResult(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultDetailScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop())
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.results,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5B3CC4),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_results.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryColor),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadResults,
                      color: AppTheme.primaryColor,
                      child: _results.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                                _EmptyResults(l10n: l10n),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _ResultCard(
                                  order: _results[index],
                                  onTap: () => _openResult(_results[index]),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyResults({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFFF3EDFF),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.science_outlined,
            size: 32,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.noResultsYet,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1433),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            l10n.noResultsSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9A93B0),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _ResultCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final file = ResultFile.fromUrl(order.reportUrl!);
    final locale = Localizations.localeOf(context).toString();
    final completedRaw = order.results?['completedAt']?.toString();
    final date = DateTime.tryParse(completedRaw ?? '') ?? order.createdAt;
    final labName = order.labData?['name']?.toString() ?? '';
    final tests = order.tests.map((t) => t.testName).take(2).join(' • ');

    final icon = switch (file.kind) {
      ResultFileKind.pdf => Icons.picture_as_pdf_rounded,
      ResultFileKind.image => Icons.image_rounded,
      ResultFileKind.other => Icons.insert_drive_file_rounded,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E0F8)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EDFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tests.isEmpty ? l10n.testResults : tests,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1C1433),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (labName.isNotEmpty) labName,
                        DateFormat('d MMM yyyy', locale).format(date.toLocal()),
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF9A93B0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.viewResult,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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
