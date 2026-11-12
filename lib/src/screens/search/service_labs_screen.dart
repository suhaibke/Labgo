import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../services/quick_service.dart';
import '../../services/lab_service.dart';
import '../../services/auth_service.dart';
import '../lab_details/lab_details_screen.dart';

/// Shows the labs currently offering a specific admin-managed quick
/// service, each with the price that lab set for it.
class ServiceLabsScreen extends StatefulWidget {
  final QuickService service;

  const ServiceLabsScreen({super.key, required this.service});

  @override
  State<ServiceLabsScreen> createState() => _ServiceLabsScreenState();
}

class _ServiceLabsScreenState extends State<ServiceLabsScreen> {
  bool _isLoading = true;
  List<ServiceLab> _labs = [];
  String? _openingLabId;
  String? _userCity;

  @override
  void initState() {
    super.initState();
    _loadLabs();
  }

  Future<void> _loadLabs() async {
    setState(() => _isLoading = true);
    if (!AuthService.isGuestMode) {
      final userData = await AuthService().getUserData();
      _userCity = userData?['city'] as String?;
    }
    final result = await QuickServiceApi.getLabsForService(
      widget.service.id,
      city: _userCity,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _labs = result['labs'] as List<ServiceLab>;
      }
    });
  }

  Future<void> _openLab(ServiceLab serviceLab) async {
    setState(() => _openingLabId = serviceLab.id);
    final token = await AuthService().getToken();
    final result = await LabService.getLabDetails(labId: serviceLab.id, token: token);
    if (!mounted) return;
    setState(() => _openingLabId = null);

    if (result['success'] == true && result['lab'] != null) {
      final lab = Lab.fromJson(result['lab'] as Map<String, dynamic>);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => LabDetailsScreen(lab: lab)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'حدث خطأ أثناء فتح المختبر'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.service.displayName('ar'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _labs.isEmpty
              ? const Center(child: Text('لا يوجد مختبر يوفر هذه الخدمة حاليًا'))
              : RefreshIndicator(
                  onRefresh: _loadLabs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _labs.length,
                    itemBuilder: (context, index) {
                      final lab = _labs[index];
                      final isOpening = _openingLabId == lab.id;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.gray100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: (lab.logo?.isNotEmpty ?? false)
                                ? CachedNetworkImage(
                                    imageUrl: lab.logo!,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.biotech_rounded),
                                  )
                                : const Icon(Icons.biotech_rounded),
                          ),
                          title: Text(
                            lab.testName?.isNotEmpty == true ? lab.testName! : lab.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            [
                              lab.name,
                              [lab.city, lab.address].where((e) => e?.isNotEmpty ?? false).join(' - '),
                            ].where((e) => e.isNotEmpty).join(' · '),
                          ),
                          trailing: lab.price != null
                              ? Text(
                                  '${lab.price} د.ع',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                )
                              : null,
                          onTap: isOpening ? null : () => _openLab(lab),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
