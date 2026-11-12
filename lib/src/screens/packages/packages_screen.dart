import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/package_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/package_card.dart';

/// Browse screen for lab-managed test bundles ("الباقات") - separate from
/// the discount-offers screen, matching the reference design: search bar,
/// category filter chips, result-count header, and a list of package cards.
class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _CategoryOption {
  final String? value;
  final String labelAr;

  const _CategoryOption(this.value, this.labelAr);
}

class _PackagesScreenState extends State<PackagesScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Package> _packages = [];
  int _labCount = 0;
  int _total = 0;
  String? _selectedCategory;
  String? _userCity;

  static const _categories = [
    _CategoryOption(null, 'الكل'),
    _CategoryOption('General', 'الصحة العامة'),
    _CategoryOption('Heart', 'القلب'),
    _CategoryOption('Diabetes', 'السكري'),
    _CategoryOption('Women', 'النساء'),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!AuthService.isGuestMode) {
      final userData = await AuthService().getUserData();
      _userCity = userData?['city'] as String?;
    }
    await _loadPackages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoading = true);
    final result = await PackageApi.getPackages(
      search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      category: _selectedCategory,
      city: _userCity,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _packages = result['packages'] as List<Package>;
        _labCount = result['labCount'] ?? 0;
        _total = (result['pagination']?['total'] as int?) ?? _packages.length;
      }
    });
  }

  void _selectCategory(String? value) {
    if (_selectedCategory == value) return;
    setState(() => _selectedCategory = value);
    _loadPackages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPackages,
          color: AppTheme.primaryColor,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                )
              else if (_packages.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'لا توجد باقات مطابقة حالياً',
                      style: TextStyle(color: AppTheme.gray500, fontSize: 14),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => PackageCard(package: _packages[index]),
                      childCount: _packages.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: AppTheme.gray900.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppTheme.gray700),
                ),
              ),
              const Spacer(),
              const Text(
                'الباقات',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.gray900),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(14)),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _loadPackages(),
              style: const TextStyle(fontSize: 14, color: AppTheme.gray900),
              decoration: const InputDecoration(
                hintText: 'إبحث عن فحص أو باقة',
                hintStyle: TextStyle(fontSize: 14, color: AppTheme.gray400),
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.gray400, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat.value;
                return GestureDetector(
                  onTap: () => _selectCategory(cat.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.white,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Text(
                      cat.labelAr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.gray700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (!_isLoading)
            Row(
              children: [
                Text(
                  '$_total باقة متاحة',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.gray900),
                ),
                const SizedBox(width: 10),
                Text(
                  '$_labCount مختبر',
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.gray500),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
