import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../ui.dart';

/// LabGo Store (design: storeTitle screen): offers, categories, products,
/// checkout, order tracking, my products, auction and labs for sale.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class StoreProduct {
  final String id, name, category, condition, description, icon, code, ownerLab;
  final int price, stock;
  final bool mine;
  const StoreProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.condition,
    required this.description,
    required this.icon,
    required this.stock,
    required this.code,
    this.mine = false,
    this.ownerLab = '',
  });
}

class StoreOrder {
  final String id, productName, code, address, phone, createdAt;
  final int quantity, total;
  int step;
  StoreOrder({
    required this.id,
    required this.productName,
    required this.code,
    required this.quantity,
    required this.total,
    required this.address,
    required this.phone,
    required this.createdAt,
    this.step = 0,
  });
}

class StoreAuction {
  final String id, name, icon, timeLeft;
  final int startingBid;
  int currentBid, bids;
  String topBidder;
  StoreAuction(this.id, this.name, this.icon, this.startingBid, this.currentBid, this.bids, this.timeLeft, this.topBidder);
}

class LabForSale {
  final String name, location, area, equipment, description;
  final int price;
  final bool sold;
  const LabForSale(this.name, this.location, this.price, this.area, this.equipment, this.description, {this.sold = false});
}

/// Demo data from the design (tw / ew / iw).
final kStoreProducts = <StoreProduct>[
  const StoreProduct(id: 'prod-1', name: 'Centrifuge', price: 850000, category: 'Device', condition: 'New', description: 'High-speed lab centrifuge', icon: 'FlaskConical', stock: 6, code: 'DEV-001', mine: true, ownerLab: 'LabGo Mosul'),
  const StoreProduct(id: 'prod-2', name: 'Microscope', price: 1200000, category: 'Device', condition: 'Used', description: 'Binocular microscope, good condition', icon: 'Microscope', stock: 2, code: 'DEV-002'),
  const StoreProduct(id: 'prod-3', name: 'Test Tubes Pack', price: 25000, category: 'Consumable', condition: 'New', description: 'Pack of 100 sterile test tubes', icon: 'TestTube', stock: 48, code: 'CON-001'),
];
final kStoreAuctions = <StoreAuction>[
  StoreAuction('auc-1', 'Centrifuge', 'FlaskConical', 500000, 620000, 7, '1d 06h', 'LabGo Mosul'),
  StoreAuction('auc-2', 'Microscope', 'Microscope', 700000, 745000, 4, '2d 11h', 'City Lab'),
];
const kLabsForSale = <LabForSale>[
  LabForSale('Al-Noor Lab', 'Mosul, Al-Majmoua St.', 45000000, '120 m²', 'Centrifuge, Microscope, Analyzer', 'Fully equipped lab, ready to work.'),
  LabForSale('City Lab', 'Erbil, 60m St.', 38000000, '95 m²', 'Centrifuge, Incubator, Test tubes', 'Established lab with full equipment.', sold: true),
];

String money(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

class _StoreScreenState extends State<StoreScreen> {
  String view = 'main'; // main | checkout | orders | order | my | auction
  String search = '';
  String category = 'All';
  int banner = 0;
  bool adding = false;
  StoreProduct? product;
  StoreOrder? order;
  int qty = 1;
  Timer? _bannerTimer;

  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _pName = TextEditingController();
  final _pPrice = TextEditingController();
  final _pCode = TextEditingController();
  final _pStock = TextEditingController();
  final _pDesc = TextEditingController();
  String _pCategory = 'Device';
  String _pCondition = 'New';
  String _pUnit = 'piece';

  @override
  void initState() {
    super.initState();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && view == 'main') setState(() => banner = (banner + 1) % 3);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    for (final c in [_address, _phone, _pName, _pPrice, _pCode, _pStock, _pDesc]) {
      c.dispose();
    }
    super.dispose();
  }

  void go(String v) => setState(() {
        view = v;
        adding = false;
      });

  void back(AppState app) {
    if (view == 'order') return go('orders');
    if (view != 'main') return go('main');
    app.closeStore();
  }

  String catLabel(AppState app, String c) => switch (c) {
        'Device' => app.tr('جهاز', 'ئامێر', 'Device'),
        'Reagent' => app.tr('كاشف', 'کاشف', 'Reagent'),
        'Consumable' => app.tr('مستهلك', 'بەکاربراو', 'Consumable'),
        _ => app.tr('الكل', 'هەموو', 'All'),
      };

  List<String> steps(AppState app) => [
        app.tr('تم الاستلام', 'وەرگیرا', 'Received'),
        app.tr('قيد التجهيز', 'ئامادەکردن', 'Preparing'),
        app.tr('تم الشحن', 'نێردرا', 'Shipped'),
        app.tr('تم التوصيل', 'گەیەندرا', 'Delivered'),
      ];

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final title = switch (view) {
      'checkout' => app.tr('إتمام الطلب', 'تەواوکردنی داواکاری', 'Checkout'),
      'orders' || 'order' => app.tr('طلباتي', 'داواکارییەکانم', 'My Orders'),
      'my' => app.tr('منتجاتي', 'بەرهەمەکانم', 'My Products'),
      'auction' => app.tr('المزاد', 'مزایدە', 'Auction'),
      _ => app.d('storeTitle'),
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 112 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Tap(
                onTap: () => back(app),
                scale: .9,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: pal.chipBg, shape: BoxShape.circle, border: Border.all(color: pal.cardBorder)),
                  child: LIcon('ArrowLeft', size: 17, color: pal.ink, flipX: app.rtl),
                ),
              ),
              const SizedBox(width: 8),
              Text(title, style: ts(context, 13, weight: w700, color: pal.muted)),
            ],
          ),
          ...switch (view) {
            'checkout' => _checkout(context),
            'orders' => _orders(context),
            'order' => _orderDetail(context),
            'my' => _myProducts(context),
            'auction' => _auction(context),
            _ => _main(context),
          },
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- main
  List<Widget> _main(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final q = search.trim().toLowerCase();
    final list = app.storeProducts
        .where((p) => category == 'All' || p.category == category)
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || p.code.toLowerCase().contains(q))
        .toList();
    final banners = [
      (app.d('bannerTitle'), app.d('bannerSub'), '850,000 IQD', [pal.accent, Color.lerp(pal.accent, Colors.white, .25)!], 'FlaskConical'),
      (app.tr('كواشف بأسعار الجملة', 'کاشف بە نرخی کۆ', 'Reagents at wholesale prices'), app.tr('خصم حتى 15% للطلبات الكبيرة', 'تا 15% داشکاندن', 'Up to 15% off bulk orders'), '25,000 IQD', [const Color(0xFFFF3B30), const Color(0xFFFF7A33)], 'TestTube'),
      (app.tr('مجاهر مستعملة بحالة ممتازة', 'میکرۆسکۆپی بەکارهاتوو', 'Used microscopes, great condition'), app.tr('فحص كامل قبل البيع', 'پشکنینی تەواو', 'Fully checked before sale'), '1,200,000 IQD', [const Color(0xFF2B2B2E), const Color(0xFF55555A)], 'Microscope'),
    ];
    final b = banners[banner];
    return [
      Text(app.d('storeTitle'), style: ts(context, 28, weight: w700, height: 1.25)),
      Text(app.d('storeSub'), style: ts(context, 13, color: pal.muted)),
      const SizedBox(height: 12),
      SearchBarBox(
        hint: app.tr('ابحث بالاسم أو الكود مثل DEV-001...', 'بەدوای ناو یان کۆد بگەڕێ...', 'Search by name or code, e.g. DEV-001...'),
        onChanged: (v) => setState(() => search = v),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 100) return;
          setState(() => banner = (banner + (v < 0 ? 1 : 2)) % 3);
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Container(
            key: ValueKey(banner),
            height: 140,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: b.$4, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                        child: Text('20% OFF', style: ts(context, 10, weight: w900, color: b.$4.first, height: 1.2)),
                      ),
                      const SizedBox(height: 6),
                      Text(b.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(context, 17, weight: w900, color: Colors.white, height: 1.2)),
                      Text(b.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(context, 12, color: Colors.white.withValues(alpha: .9), height: 1.35)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(b.$3, style: ts(context, 13, weight: w900, color: Colors.white)),
                          const SizedBox(width: 8),
                          Tap(
                            onTap: () => setState(() => category = 'Device'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                              child: Text(app.d('shopNow'), style: ts(context, 12, weight: w700, color: const Color(0xFF111111))),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .25), borderRadius: BorderRadius.circular(14)),
                  child: LIcon(b.$5, size: 44, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            GestureDetector(
              onTap: () => setState(() => banner = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: banner == i ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(color: banner == i ? pal.accent : pal.track, borderRadius: BorderRadius.circular(999)),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _pill(context, 'Plus', app.d('storeAdd'), () => setState(() => adding = !adding), filled: true),
            _pill(context, 'ShoppingCart', '${app.tr('طلباتي', 'داواکارییەکانم', 'My Orders')}${app.storeOrders.isEmpty ? '' : ' (${app.storeOrders.length})'}', () => go('orders')),
            _pill(context, 'Package', '${app.tr('منتجاتي', 'بەرهەمەکانم', 'My Products')} (${app.storeProducts.where((p) => p.mine).length})', () => go('my')),
            _pill(context, 'Gavel', '${app.tr('المزاد', 'مزایدە', 'Auction')} (${kStoreAuctions.length})', () => go('auction')),
          ],
        ),
      ),
      if (adding) ...[const SizedBox(height: 12), _addForm(context)],
      const SizedBox(height: 16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in const ['All', 'Device', 'Reagent', 'Consumable']) ...[
              FilterChipPill(label: catLabel(app, c), selected: category == c, onTap: () => setState(() => category = c)),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (final p in list) ...[_productCard(context, p), const SizedBox(height: 12)],
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(app.tr('لا توجد منتجات مطابقة', 'هیچ بەرهەمێک نییە', 'No matching products'), textAlign: TextAlign.center, style: ts(context, 13, color: pal.muted)),
        ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: Text(app.tr('مختبرات للبيع', 'تاقیگەکان بۆ فرۆشتن', 'Labs for Sale'), style: ts(context, 20, weight: w900))),
          Text('${kLabsForSale.length}', style: ts(context, 12, weight: w700, color: pal.muted)),
        ],
      ),
      Text(app.tr('مختبرات كاملة للبيع مع أجهزتها', 'تاقیگەی تەواو لەگەڵ ئامێرەکانی', 'Complete labs for sale with their equipment'), style: ts(context, 13, color: pal.muted)),
      const SizedBox(height: 12),
      for (final l in kLabsForSale) ...[
        CardBox(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(16)),
                child: LIcon('Building2', size: 24, color: pal.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(l.name, style: ts(context, 15, weight: w700))),
                        _badge(context, l.sold ? app.tr('مباع', 'فرۆشرا', 'Sold') : app.tr('متاح', 'بەردەستە', 'Available'), l.sold ? pal.muted : pal.greenText, l.sold ? pal.chipBg : pal.softGreen),
                      ],
                    ),
                    Text('${l.location} • ${l.area}', style: ts(context, 12, color: pal.muted)),
                    Text(l.equipment, style: ts(context, 12, color: pal.muted2)),
                    const SizedBox(height: 4),
                    Text('${money(l.price)} IQD', style: ts(context, 15, weight: w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _pill(BuildContext context, String icon, String label, VoidCallback onTap, {bool filled = false}) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Tap(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: filled ? pal.accent : pal.chipBg,
            borderRadius: BorderRadius.circular(999),
            border: filled ? null : Border.all(color: pal.cardBorder),
          ),
          child: Row(
            children: [
              LIcon(icon, size: 15, color: filled ? Colors.white : pal.ink),
              const SizedBox(width: 6),
              Text(label, style: ts(context, 13, weight: w700, color: filled ? Colors.white : pal.ink)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: ts(context, 11, weight: w700, color: fg, height: 1.45)),
      );

  Widget _productCard(BuildContext context, StoreProduct p) {
    final app = context.app;
    final pal = app.palette;
    return Tap(
      onTap: () => setState(() {
        product = p;
        qty = 1;
        _address.text = app.userAddress;
        _phone.text = app.userPhone;
        view = 'checkout';
      }),
      scale: .98,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: pal.cardBorder),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 150,
              color: pal.chipBg,
              child: Stack(
                children: [
                  Center(child: LIcon(p.icon, size: 56, color: pal.accent)),
                  PositionedDirectional(
                    top: 8,
                    start: 8,
                    child: _badge(context, '${app.tr('كود: ', 'کۆد: ', '')}${p.code}', Colors.white, Colors.black.withValues(alpha: .6)),
                  ),
                  PositionedDirectional(
                    bottom: 8,
                    start: 8,
                    child: _badge(context, catLabel(app, p.category), const Color(0xFF111111), Colors.white.withValues(alpha: .9)),
                  ),
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), shape: BoxShape.circle),
                      child: LIcon('ShoppingCart', size: 17, color: pal.accent),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(p.name, style: ts(context, 15, weight: w700))),
                      const SizedBox(width: 8),
                      _badge(
                        context,
                        p.condition == 'New' ? app.d('newC') : app.d('used'),
                        p.condition == 'New' ? pal.greenText : const Color(0xFF8A5A00),
                        p.condition == 'New' ? pal.softGreen : const Color(0xFFFFF4D6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(p.description.isEmpty ? app.d('productDescFallback') : p.description, style: ts(context, 12, color: pal.muted, height: 1.4)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text('${money(p.price)} IQD', style: ts(context, 15, weight: w700))),
                      Text('${app.tr('المخزون', 'کۆگا', 'Stock')}: ${p.stock}', style: ts(context, 11, color: pal.muted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 10),
        child: Text(t, style: ts(context, 12, weight: w700, color: context.pal.muted)),
      );

  Widget _addForm(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    Widget seg(List<(String, String)> opts, String value, void Function(String) on) => Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: pal.segmented, borderRadius: BorderRadius.circular(999)),
          child: Row(
            children: [
              for (final o in opts)
                Expanded(
                  child: Tap(
                    onTap: () => setState(() => on(o.$1)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: value == o.$1 ? pal.ink : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                      child: Text(o.$2, style: ts(context, 13, weight: w700, color: value == o.$1 ? pal.appBg : pal.muted2)),
                    ),
                  ),
                ),
            ],
          ),
        );
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(app.d('addProduct'), style: ts(context, 15, weight: w700))),
              Tap(
                onTap: () => setState(() => adding = false),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: pal.chipBg, shape: BoxShape.circle),
                  child: LIcon('X', size: 16, color: pal.ink),
                ),
              ),
            ],
          ),
          _label(context, app.d('productName')),
          BoxField(controller: _pName, hint: 'Centrifuge'),
          _label(context, app.d('productPrice')),
          BoxField(controller: _pPrice, hint: '850000', keyboard: TextInputType.number, ltr: true),
          _label(context, app.tr('كود المنتج', 'کۆدی بەرهەم', 'Product Code')),
          BoxField(controller: _pCode, hint: 'DEV-023', ltr: true),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(app.tr('اتركه فارغاً ليتم إنشاؤه تلقائياً', 'بەتاڵی بهێڵە بۆ دروستکردنی خۆکار', 'Leave empty to generate it automatically'), style: ts(context, 11, color: pal.muted)),
          ),
          _label(context, app.d('category')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in const ['Device', 'Reagent', 'Consumable'])
                FilterChipPill(label: catLabel(app, c), selected: _pCategory == c, onTap: () => setState(() => _pCategory = c)),
            ],
          ),
          _label(context, app.tr('الكمية (المخزون) — مطلوب', 'بڕ (کۆگا) — پێویستە', 'Quantity (stock) — required')),
          Row(
            children: [
              Expanded(child: BoxField(controller: _pStock, hint: '48', keyboard: TextInputType.number, ltr: true)),
              const SizedBox(width: 8),
              Expanded(
                child: seg([
                  ('piece', app.tr('قطعة', 'پارچە', 'piece')),
                  ('box', app.tr('علبة', 'قوتوو', 'box')),
                  ('carton', app.tr('كرتون', 'کارتۆن', 'carton')),
                ], _pUnit, (v) => _pUnit = v),
              ),
            ],
          ),
          _label(context, app.d('condition')),
          seg([('New', app.d('newC')), ('Used', app.d('used'))], _pCondition, (v) => _pCondition = v),
          _label(context, app.d('description')),
          BoxField(controller: _pDesc, lines: 3, fontSize: 14),
          const SizedBox(height: 12),
          Tap(
            onTap: () {
              final name = _pName.text.trim();
              final price = int.tryParse(_pPrice.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              final stock = int.tryParse(_pStock.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              if (name.isEmpty || price <= 0 || stock <= 0) {
                app.toast(app.tr('أكمل الاسم والسعر والكمية', 'ناو و نرخ و بڕ پڕ بکەرەوە', 'Fill in the name, price and quantity'));
                return;
              }
              final prefix = _pCategory == 'Device' ? 'DEV' : _pCategory == 'Consumable' ? 'CON' : 'REA';
              final n = app.storeProducts.where((p) => p.category == _pCategory).length + 1;
              app.addStoreProduct(StoreProduct(
                id: 'prod-${DateTime.now().millisecondsSinceEpoch}',
                name: name,
                price: price,
                category: _pCategory,
                condition: _pCondition,
                description: _pDesc.text.trim(),
                icon: _pCategory == 'Device' ? 'Microscope' : _pCategory == 'Reagent' ? 'FlaskConical' : 'TestTube',
                stock: stock,
                code: _pCode.text.trim().isEmpty ? '$prefix-${n.toString().padLeft(3, '0')}' : _pCode.text.trim().toUpperCase(),
                mine: true,
                ownerLab: app.labDisplayName,
              ));
              for (final c in [_pName, _pPrice, _pCode, _pStock, _pDesc]) {
                c.clear();
              }
              setState(() => adding = false);
              app.toast(app.d('productAdded'));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: pal.accent, borderRadius: BorderRadius.circular(999)),
              child: Text(app.d('addProductBtn'), style: ts(context, 15, weight: w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ checkout
  List<Widget> _checkout(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final p = product!;
    Widget round(String t, bool accent, VoidCallback on) => Tap(
          onTap: on,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent ? pal.accent : pal.card, shape: BoxShape.circle, border: accent ? null : Border.all(color: pal.cardBorder)),
            child: Text(t, style: ts(context, 20, weight: w900, color: accent ? Colors.white : pal.ink, height: 1)),
          ),
        );
    return [
      const SizedBox(height: 4),
      Text(app.tr('إتمام الطلب', 'تەواوکردنی داواکاری', 'Checkout'), style: ts(context, 26, weight: w700, height: 1.25)),
      const SizedBox(height: 12),
      CardBox(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(16)),
                  child: LIcon(p.icon, size: 26, color: pal.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: ts(context, 16, weight: w700)),
                      Text(p.code, style: ts(context, 12, color: pal.muted)),
                      Text('${money(p.price)} IQD', style: ts(context, 14, weight: w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(999)),
              child: Row(
                children: [
                  round('−', false, () => setState(() => qty = qty > 1 ? qty - 1 : 1)),
                  Expanded(
                    child: Column(
                      children: [
                        Text('$qty', style: ts(context, 20, weight: w700, height: 1)),
                        Text(app.tr('الكمية', 'بڕ', 'Quantity'), style: ts(context, 11, color: pal.muted)),
                      ],
                    ),
                  ),
                  round('+', true, () => setState(() => qty = qty < p.stock ? qty + 1 : p.stock)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(app.tr('الإجمالي', 'کۆی گشتی', 'Total'), style: ts(context, 14, weight: w700, color: pal.muted))),
                Text('${money(p.price * qty)} IQD', style: ts(context, 18, weight: w700)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(app.tr('العنوان', 'ناونیشان', 'Address'), style: ts(context, 12, weight: w700, color: pal.muted)),
            const SizedBox(height: 4),
            BoxField(controller: _address),
            Text(app.tr('مأخوذ من الملف الشخصي — يمكنك تعديله هنا', 'لە پرۆفایلەوە — دەتوانیت بیگۆڕیت', 'From your profile — you can change it here'), style: ts(context, 11, color: pal.muted)),
            const SizedBox(height: 10),
            Text(app.tr('رقم الهاتف', 'ژمارەی تەلەفۆن', 'Phone Number'), style: ts(context, 12, weight: w700, color: pal.muted)),
            const SizedBox(height: 4),
            BoxField(controller: _phone, ltr: true, keyboard: TextInputType.phone),
            Text(app.tr('متزامن مع رقم الملف الشخصي', 'لەگەڵ ژمارەی پرۆفایل هاوکاتە', 'Synced with your profile number'), style: ts(context, 11, color: pal.muted)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Tap(
        onTap: () {
          if (_address.text.trim().isEmpty || _phone.text.trim().isEmpty) {
            app.toast(app.tr('أكمل العنوان ورقم الهاتف', 'ناونیشان و ژمارە پڕ بکەرەوە', 'Fill in the address and phone'));
            return;
          }
          final n = DateTime.now();
          final o = StoreOrder(
            id: '${n.millisecondsSinceEpoch}',
            productName: p.name,
            code: p.code,
            quantity: qty,
            total: p.price * qty,
            address: _address.text.trim(),
            phone: _phone.text.trim(),
            createdAt: '${n.day}/${n.month}/${n.year}',
          );
          app.addStoreOrder(o);
          app.toast(app.tr('تم تأكيد الطلب ✓', 'داواکاری پشتڕاستکرایەوە ✓', 'Order confirmed ✓'));
          setState(() {
            order = o;
            view = 'order';
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: pal.accent, borderRadius: BorderRadius.circular(999)),
          child: Text('${app.tr('تأكيد الطلب', 'پشتڕاستکردنەوەی داواکاری', 'Confirm Order')} • ${money(p.price * qty)} IQD', style: ts(context, 15, weight: w700, color: Colors.white)),
        ),
      ),
    ];
  }

  // -------------------------------------------------------------- orders
  List<Widget> _orders(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final st = steps(app);
    return [
      const SizedBox(height: 4),
      Text(app.tr('تتبع الطلب', 'شوێنکەوتنی داواکاری', 'Order Tracking'), style: ts(context, 26, weight: w700, height: 1.25)),
      Text('${app.tr('طلباتي', 'داواکارییەکانم', 'My Orders')} • ${app.storeOrders.length}', style: ts(context, 13, color: pal.muted)),
      const SizedBox(height: 12),
      for (final o in app.storeOrders) ...[
        Tap(
          onTap: () => setState(() {
            order = o;
            view = 'order';
          }),
          scale: .98,
          child: CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(o.productName, style: ts(context, 15, weight: w700))),
                    _badge(context, st[o.step], pal.accent, pal.softAccent),
                  ],
                ),
                Text('${o.code} • ${app.tr('الكمية', 'بڕ', 'Qty')}: ${o.quantity}', style: ts(context, 12, color: pal.muted)),
                Text('${money(o.total)} IQD', style: ts(context, 14, weight: w700)),
                Text('${app.tr('رقم الطلب', 'ژمارەی داواکاری', 'Order ID')}: ${o.id.substring(o.id.length - 6).toUpperCase()}', style: ts(context, 12, color: pal.muted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (app.storeOrders.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(app.tr('لا توجد طلبات بعد', 'هێشتا داواکاری نییە', 'No orders yet'), textAlign: TextAlign.center, style: ts(context, 13, color: pal.muted)),
        ),
    ];
  }

  List<Widget> _orderDetail(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final o = order!;
    final st = steps(app);
    Widget cell(String k, String v, {bool wide = false}) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k, style: ts(context, 11, weight: w700, color: pal.muted)),
              Text(v, style: ts(context, 14, weight: w700)),
            ],
          ),
        );
    return [
      const SizedBox(height: 4),
      Text(app.tr('تتبع الطلب', 'شوێنکەوتنی داواکاری', 'Order Tracking'), style: ts(context, 26, weight: w700, height: 1.25)),
      const SizedBox(height: 12),
      CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(app.tr('رقم الطلب', 'ژمارەی داواکاری', 'Order ID'), style: ts(context, 12, weight: w700, color: pal.muted))),
                _badge(context, st[o.step], Colors.white, pal.accent),
              ],
            ),
            Text('ORD-${o.id.substring(o.id.length - 6).toUpperCase()}', style: ts(context, 18, weight: w700)),
            Text('${o.createdAt} • ${o.productName} • ${o.code}', style: ts(context, 13, color: pal.muted)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: cell(app.tr('الكمية', 'بڕ', 'Quantity'), '${o.quantity}')),
                const SizedBox(width: 8),
                Expanded(child: cell(app.tr('الإجمالي', 'کۆی گشتی', 'Total'), '${money(o.total)} IQD')),
              ],
            ),
            const SizedBox(height: 8),
            cell(app.tr('العنوان', 'ناونیشان', 'Address'), o.address),
            const SizedBox(height: 8),
            cell(app.tr('رقم الهاتف', 'ژمارەی تەلەفۆن', 'Phone Number'), o.phone),
          ],
        ),
      ),
      const SizedBox(height: 12),
      CardBox(
        child: Column(
          children: [
            for (var i = 0; i < st.length; i++)
              Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: i <= o.step ? pal.accent : pal.track, shape: BoxShape.circle),
                        child: i <= o.step ? const LIcon('Check', size: 12, color: Colors.white) : null,
                      ),
                      if (i < st.length - 1) Container(width: 2, height: 24, color: i < o.step ? pal.accent : pal.track),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i < st.length - 1 ? 24 : 0),
                      child: Text(st[i], style: ts(context, 14, weight: i == o.step ? w700 : w500, color: i <= o.step ? pal.ink : pal.muted)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ];
  }

  // --------------------------------------------------------- my products
  List<Widget> _myProducts(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final mine = app.storeProducts.where((p) => p.mine).toList();
    return [
      const SizedBox(height: 4),
      Text(app.tr('منتجاتي', 'بەرهەمەکانم', 'My Products'), style: ts(context, 26, weight: w700, height: 1.25)),
      Text(app.tr('المنتجات التي يعرضها مختبرك في المتجر', 'ئەو بەرهەمانەی تاقیگەکەت دەیفرۆشێت', 'Products your lab sells in the store'), style: ts(context, 13, color: pal.muted)),
      const SizedBox(height: 12),
      for (final p in mine) ...[
        CardBox(
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(16)),
                child: LIcon(p.icon, size: 24, color: pal.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: ts(context, 15, weight: w700)),
                    Text('${p.code} • ${app.tr('المخزون', 'کۆگا', 'Stock')}: ${p.stock}', style: ts(context, 12, color: pal.muted)),
                    Text('${money(p.price)} IQD', style: ts(context, 14, weight: w700)),
                  ],
                ),
              ),
              Tap(
                onTap: () => app.removeStoreProduct(p.id),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: pal.chipBg, shape: BoxShape.circle),
                  child: const LIcon('Trash2', size: 16, color: Color(0xFFFF3B30)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (mine.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(app.tr('لم تضف منتجات بعد', 'هێشتا بەرهەمت زیاد نەکردووە', 'No products yet'), textAlign: TextAlign.center, style: ts(context, 13, color: pal.muted)),
        ),
      Tap(
        onTap: () => setState(() {
          view = 'main';
          adding = true;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: pal.accent, borderRadius: BorderRadius.circular(999)),
          child: Text(app.d('addProduct'), style: ts(context, 15, weight: w700, color: Colors.white)),
        ),
      ),
    ];
  }

  // ------------------------------------------------------------- auction
  List<Widget> _auction(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    return [
      const SizedBox(height: 4),
      Text(app.tr('المزاد', 'مزایدە', 'Auction'), style: ts(context, 26, weight: w700, height: 1.25)),
      Text(app.tr('زايد على أجهزة المختبرات الأخرى', 'مزایدە لەسەر ئامێرەکان', 'Bid on devices from other labs'), style: ts(context, 13, color: pal.muted)),
      const SizedBox(height: 12),
      for (final a in kStoreAuctions) ...[
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(16)),
                    child: LIcon(a.icon, size: 26, color: pal.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: ts(context, 16, weight: w700)),
                        Text('${app.tr('يبدأ من', 'دەستپێک', 'Starts at')} ${money(a.startingBid)} IQD', style: ts(context, 12, color: pal.muted)),
                      ],
                    ),
                  ),
                  _badge(context, '⏱ ${a.timeLeft}', pal.accent, pal.softAccent),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.tr('أعلى مزايدة', 'بەرزترین مزایدە', 'Current bid'), style: ts(context, 11, weight: w700, color: pal.muted)),
                        Text('${money(a.currentBid)} IQD', style: ts(context, 18, weight: w700)),
                        Text('${a.bids} ${app.tr('مزايدات', 'مزایدە', 'bids')} • ${a.topBidder}', style: ts(context, 12, color: pal.muted)),
                      ],
                    ),
                  ),
                  Tap(
                    onTap: () {
                      setState(() {
                        a.currentBid += 25000;
                        a.bids++;
                        a.topBidder = app.labDisplayName;
                      });
                      app.toast('${app.tr('مزايدتك', 'مزایدەکەت', 'Your bid')}: ${money(a.currentBid)} IQD');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: pal.accent, borderRadius: BorderRadius.circular(999)),
                      child: Text('+25,000', style: ts(context, 14, weight: w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}
