import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/custody_service.dart';
import '../../../l10n/app_localizations.dart';

class CustodyScreen extends StatefulWidget {
  const CustodyScreen({super.key});

  @override
  State<CustodyScreen> createState() => _CustodyScreenState();
}

class _CustodyScreenState extends State<CustodyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingCatalog = true;
  List<CustodyCatalogEntry> _catalog = [];

  bool _isLoadingRequests = true;
  List<CustodyRequestModel> _requests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCatalog();
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoadingCatalog = true);
    final result = await CustodyService.getCatalog();
    if (!mounted) return;
    setState(() {
      _isLoadingCatalog = false;
      if (result['success'] == true) {
        _catalog = result['catalog'] as List<CustodyCatalogEntry>;
      }
    });
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoadingRequests = true);
    final result = await CustodyService.getMyRequests();
    if (!mounted) return;
    setState(() {
      _isLoadingRequests = false;
      if (result['success'] == true) {
        _requests = result['requests'] as List<CustodyRequestModel>;
      }
    });
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'equipment':
        return 'معدات';
      case 'consumable':
        return 'مستلزمات';
      case 'sensitive':
        return 'مواد حساسة';
      case 'financial':
        return 'أمانات مالية';
      default:
        return category;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'equipment':
        return Icons.medical_services_outlined;
      case 'consumable':
        return Icons.inventory_2_outlined;
      case 'sensitive':
        return Icons.science_outlined;
      case 'financial':
        return Icons.payments_outlined;
      default:
        return Icons.inventory_outlined;
    }
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'approved':
        return 'موافق عليها، بانتظار التسليم';
      case 'rejected':
        return 'مرفوضة';
      case 'delivered':
        return l10n.custodyStatusInUse;
      case 'return_requested':
        return 'بانتظار تأكيد الإرجاع';
      case 'returned':
        return l10n.custodyStatusReturned;
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return const Color(0xFF2A5EDB);
      case 'approved':
        return const Color(0xFF5856D6);
      case 'return_requested':
        return const Color(0xFFC05621);
      case 'rejected':
        return const Color(0xFFC53030);
      default:
        return const Color(0xFFB8860B);
    }
  }

  Future<void> _openRequestSheet(CustodyCatalogEntry entry) async {
    final durationController = TextEditingController(text: '1');

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text('متوفر: ${entry.available} من ${entry.total}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 16),
            const Text('كم يومًا ستحتاج هذه الأمانة؟', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: 'يوم',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('إرسال الطلب'),
              ),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted) return;

    final days = int.tryParse(durationController.text.trim()) ?? 1;
    final result = await CustodyService.createRequest(
      itemName: entry.name,
      requestedDurationDays: days.clamp(1, 365),
    );

    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلبك، بانتظار موافقة الإدارة'), backgroundColor: AppTheme.success),
      );
      _tabController.animateTo(1);
      _loadRequests();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'حدث خطأ'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _initiateReturn(CustodyRequestModel request) async {
    final result = await CustodyService.initiateReturn(request.id);
    if (!mounted) return;

    if (result['success'] == true) {
      _loadRequests();
      _showReturnCodeDialog((result['request'] as CustodyRequestModel).returnCode ?? '');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'حدث خطأ'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showReturnCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('أرِ هذا الرمز للإدارة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اذهب إلى الأدمن حاملًا الأمانة، ودعه يمسح هذا الرمز لتأكيد استلامها.'),
            const SizedBox(height: 20),
            if (code.isNotEmpty)
              QrImageView(data: code, size: 200)
            else
              const Text('تعذّر توليد الرمز'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myCustody),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الكتالوج'),
            Tab(text: 'طلباتي'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCatalogTab(),
          _buildRequestsTab(l10n),
        ],
      ),
    );
  }

  Widget _buildCatalogTab() {
    if (_isLoadingCatalog) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_catalog.isEmpty) {
      return const Center(child: Text('لا توجد أمانات متاحة حاليًا للطلب'));
    }
    return RefreshIndicator(
      onRefresh: _loadCatalog,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _catalog.length,
        itemBuilder: (context, index) {
          final entry = _catalog[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_categoryIcon(entry.category), color: AppTheme.primaryColor),
              ),
              title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${_categoryLabel(entry.category)} · متوفر: ${entry.available} من ${entry.total}'),
              trailing: ElevatedButton(
                onPressed: () => _openRequestSheet(entry),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(64, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('طلب'),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsTab(AppLocalizations l10n) {
    if (_isLoadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_requests.isEmpty) {
      return Center(child: Text(l10n.custodyEmptyState));
    }
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final request = _requests[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(request.itemName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(request.status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(l10n, request.status),
                          style: TextStyle(
                            color: _statusColor(request.status),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('المدة المطلوبة: ${request.requestedDurationDays} يوم',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  if (request.expectedReturnDate != null)
                    Text(
                      'موعد الإرجاع المتوقع: ${request.expectedReturnDate!.day}/${request.expectedReturnDate!.month}/${request.expectedReturnDate!.year}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  if (request.status == 'rejected' && (request.rejectionReason?.isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('سبب الرفض: ${request.rejectionReason}',
                          style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                    ),
                  if (request.status == 'delivered' || request.status == 'return_requested') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: request.status == 'delivered'
                            ? () => _initiateReturn(request)
                            : () => _showReturnCodeDialog(request.returnCode ?? ''),
                        icon: Icon(request.status == 'delivered'
                            ? Icons.assignment_return_outlined
                            : Icons.qr_code_rounded),
                        label: Text(request.status == 'delivered' ? l10n.returnItem : 'عرض رمز الإرجاع', overflow: TextOverflow.ellipsis, maxLines: 1),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
