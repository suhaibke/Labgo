import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../ui.dart';

/// LabGo Store: the labs' marketplace. Products, auctions (a device or a whole
/// lab) and labs for sale. A lab's listing shows to others only after the
/// LabGo admin approves it; the lab sees its own listings with their status.

class StoreOrder {
  final String id, kind, productName, code, address, phone, createdAt, otherLab, note;
  final int orderNo, quantity, total;
  /// buyer = this lab bought it; seller = another lab ordered this lab's listing.
  final String role;
  String status; // new | preparing | shipped | delivered | cancelled
  StoreOrder({
    required this.id,
    required this.productName,
    required this.code,
    required this.quantity,
    required this.total,
    required this.address,
    required this.phone,
    required this.createdAt,
    this.orderNo = 0,
    this.kind = 'purchase',
    this.otherLab = '',
    this.note = '',
    this.role = 'buyer',
    this.status = 'new',
  });

  static StoreOrder fromJson(Map<String, dynamic> j) {
    final d = DateTime.tryParse('${j['createdAt'] ?? ''}')?.toLocal();
    return StoreOrder(
      id: '${j['id'] ?? ''}',
      orderNo: (j['orderNo'] as num?)?.toInt() ?? 0,
      kind: '${j['kind'] ?? 'purchase'}',
      productName: '${j['title'] ?? ''}',
      code: '${j['code'] ?? ''}',
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      total: (j['total'] as num?)?.toInt() ?? 0,
      address: '${j['address'] ?? ''}',
      phone: '${j['phone'] ?? ''}',
      note: '${j['note'] ?? ''}',
      otherLab: '${j['otherLab'] ?? ''}',
      role: '${j['role'] ?? 'buyer'}',
      status: '${j['status'] ?? 'new'}',
      createdAt: d == null ? '' : '${d.day}/${d.month}/${d.year}',
    );
  }
}

String money(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String view = 'main'; // main | add | detail | checkout | orders | mine | auction
  String search = '';
  String category = 'All';
  MarketItem? item;
  int qty = 1;
  final _address = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _from = 'main';
  void go(String v, {MarketItem? it}) => setState(() {
        if (v == 'detail') _from = view == 'auction' ? 'auction' : 'main';
        view = v;
        if (it != null) item = it;
      });

  void back(AppState app) {
    if (view == 'checkout') return go('detail');
    if (view == 'detail' && _from == 'auction') return go('auction');
    if (view != 'main') return go('main');
    app.closeStore();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final title = switch (view) {
      'add' => app.tr('إضافة للمتجر', 'زیادکردن', 'Add to store'),
      'checkout' => app.tr('إتمام الطلب', 'تەواوکردنی داواکاری', 'Checkout'),
      'orders' => app.tr('طلباتي', 'داواکارییەکانم', 'My Orders'),
      'mine' => app.tr('معروضاتي', 'بەرهەمەکانم', 'My listings'),
      'auction' => app.tr('المزاد', 'مزایدە', 'Auction'),
      'detail' => item?.title ?? '',
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
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(context, 13, weight: w700, color: pal.muted))),
            ],
          ),
          ...switch (view) {
            'add' => [_AddListing(onDone: () => go('mine'))],
            'detail' => [_Detail(item: _fresh(app, item!), onBuy: () => go('checkout'))],
            'checkout' => _checkout(context),
            'orders' => _orders(context),
            'mine' => _mine(context),
            'auction' => _auctionView(context),
            _ => _main(context),
          },
        ],
      ),
    );
  }

  MarketItem _fresh(AppState app, MarketItem it) => app.marketItems.firstWhere((m) => m.id == it.id, orElse: () => it);

  String catLabel(AppState app, String c) => switch (c) {
        'Device' => app.tr('جهاز', 'ئامێر', 'Device'),
        'Reagent' => app.tr('كاشف', 'کاشف', 'Reagent'),
        'Consumable' => app.tr('مستهلك', 'بەکاربراو', 'Consumable'),
        _ => app.tr('الكل', 'هەموو', 'All'),
      };

  // ---------------------------------------------------------------- main
  List<Widget> _main(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final q = search.trim().toLowerCase();
    bool match(MarketItem m) => q.isEmpty || m.title.toLowerCase().contains(q) || m.code.toLowerCase().contains(q) || m.labName.toLowerCase().contains(q);
    final live = app.marketItems.where((m) => m.approved && m.status != 'removed').toList();
    final products = live.where((m) => m.kind == 'product' && (category == 'All' || m.category == category) && match(m)).toList();
    final auctions = live.where((m) => m.isAuction && m.status == 'active' && match(m)).toList();
    final labs = live.where((m) => m.kind == 'lab_sale' && match(m)).toList();
    final mineCount = app.marketItems.where((m) => m.mine).length;
    return [
      Text(app.d('storeTitle'), style: ts(context, 28, weight: w700, height: 1.25)),
      Text(app.d('storeSub'), style: ts(context, 13, color: pal.muted)),
      const SizedBox(height: 12),
      SearchBarBox(
        hint: app.tr('ابحث بالاسم أو الكود أو المختبر…', 'بگەڕێ…', 'Search by name, code or lab…'),
        onChanged: (v) => setState(() => search = v),
      ),
      const SizedBox(height: 12),
      _StoreBanner(
        images: app.storeBanners,
        onTapImage: (i) {
          final link = i < app.storeBannerLinks.length ? app.storeBannerLinks[i] : '';
          if (link.isEmpty) return;
          final it = app.listingForLink(link);
          if (it != null) {
            go('detail', it: it);
          } else {
            app.openExternalLink(link);
          }
        },
        seconds: app.storeBannerSeconds,
        // Built-in slides, shown until the admin uploads store banners.
        fallback: [
          _Slide(app.tr('متجر LabGo للمختبرات', 'فرۆشگای LabGo', 'LabGo store for labs'), app.tr('بيع واشترِ الأجهزة والمواد مباشرة بين المختبرات', 'ئامێر و کەرەستە لە نێوان تاقیگەکان بکڕە و بفرۆشە', 'Buy and sell devices and supplies between labs'),
              app.tr('تصفح المنتجات', 'بەرهەمەکان', 'Browse products'), 'Package', pal.accent, () => setState(() => category = 'All')),
          _Slide(app.tr('المزاد', 'مزایدە', 'Auction'), app.tr('زايد على أجهزة ومختبرات معروضة من مختبرات أخرى', 'نرخ بدە لەسەر ئامێر و تاقیگەکان', 'Bid on devices and labs listed by other labs'),
              app.tr('افتح المزاد', 'کردنەوەی مزایدە', 'Open auctions'), 'Gavel', const Color(0xFF17191E), () => go('auction')),
          _Slide(app.tr('اعرض أجهزتك أو مختبرك للبيع', 'ئامێرەکانت یان تاقیگەکەت بفرۆشە', 'Sell your devices or your lab'), app.tr('أضف إعلانك ويظهر للمختبرات بعد موافقة الإدارة', 'دوای ڕەزامەندی بەڕێوەبەر دەردەکەوێت', 'Add a listing; labs see it after admin approval'),
              app.tr('إضافة إعلان', 'زیادکردن', 'Add listing'), 'Plus', const Color(0xFF2563EB), () => go('add')),
        ],
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _pill(context, 'Plus', app.d('storeAdd'), () => go('add'), filled: true),
            _pill(context, 'Gavel', '${app.tr('المزاد', 'مزایدە', 'Auction')}${auctions.isEmpty ? '' : ' (${auctions.length})'}', () => go('auction')),
            _pill(context, 'Package', '${app.tr('معروضاتي', 'بەرهەمەکانم', 'My listings')}${mineCount > 0 ? ' ($mineCount)' : ''}', () => go('mine')),
            _pill(context, 'ShoppingCart', '${app.tr('طلباتي', 'داواکارییەکانم', 'My Orders')}${app.storeOrders.length + app.storeIncoming.length == 0 ? '' : ' (${app.storeOrders.length + app.storeIncoming.length})'}', () => go('orders')),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Tap(
        onTap: () => go('auction'),
        child: _sectionTitle(context, app.tr('المزاد', 'مزایدە', 'Auction'), auctions.length, more: app.tr('عرض الكل', 'هەموو', 'View all')),
      ),
      const SizedBox(height: 8),
      if (auctions.isEmpty)
        _empty(context, app.tr('لا توجد مزادات جارية الآن — أضف مزادك من «إضافة»', 'ئێستا هیچ مزایدەیەک نییە', 'No live auctions right now — add yours from “Add”'))
      else
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: auctions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(width: 220, child: _AuctionCard(item: auctions[i], onTap: () => go('detail', it: auctions[i]))),
          ),
        ),
      const SizedBox(height: 18),
      _sectionTitle(context, app.tr('المنتجات', 'بەرهەمەکان', 'Products'), products.length),
      const SizedBox(height: 8),
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
      for (final p in products) ...[_ListingCard(item: p, onTap: () => go('detail', it: p)), const SizedBox(height: 12)],
      if (products.isEmpty) _empty(context, app.tr('لا توجد منتجات معروضة بعد', 'هێشتا بەرهەم نییە', 'No products listed yet')),
      const SizedBox(height: 12),
      _sectionTitle(context, app.tr('مختبرات للبيع', 'تاقیگەکان بۆ فرۆشتن', 'Labs for Sale'), labs.length),
      Text(app.tr('مختبرات كاملة للبيع مع أجهزتها', 'تاقیگەی تەواو لەگەڵ ئامێرەکانی', 'Complete labs for sale with their equipment'), style: ts(context, 13, color: pal.muted)),
      const SizedBox(height: 12),
      for (final l in labs) ...[_ListingCard(item: l, onTap: () => go('detail', it: l)), const SizedBox(height: 12)],
      if (labs.isEmpty) _empty(context, app.tr('لا توجد مختبرات معروضة للبيع', 'هیچ تاقیگەیەک نییە', 'No labs for sale yet')),
    ];
  }

  Widget _sectionTitle(BuildContext context, String t, int n, {String? more}) => Row(
        children: [
          Expanded(child: Text(t, style: ts(context, 20, weight: w900))),
          if (more != null)
            Text(more, style: ts(context, 13, weight: w700, color: context.pal.accent))
          else
            Text('$n', style: ts(context, 12, weight: w700, color: context.pal.muted)),
        ],
      );

  // ------------------------------------------------------------- auction
  /// Every approved auction (devices and labs): live ones first, then ended.
  List<Widget> _auctionView(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final all = app.marketItems.where((m) => m.approved && m.isAuction && m.status != 'removed').toList()
      ..sort((a, b) {
        final la = a.status == 'active' ? 0 : 1, lb = b.status == 'active' ? 0 : 1;
        if (la != lb) return la - lb;
        return (a.endsAt ?? DateTime(2100)).compareTo(b.endsAt ?? DateTime(2100));
      });
    return [
      Text(app.tr('المزاد', 'مزایدە', 'Auction'), style: ts(context, 26, weight: w700, height: 1.25)),
      Text(app.tr('زايد على أجهزة ومختبرات معروضة من مختبرات أخرى', 'نرخ بدە لەسەر ئامێر و تاقیگەکان', 'Bid on devices and labs listed by other labs'), style: ts(context, 13, color: pal.muted)),
      const SizedBox(height: 12),
      if (all.isEmpty) _empty(context, app.tr('لا توجد مزادات بعد', 'هێشتا مزایدە نییە', 'No auctions yet')),
      for (final a in all) ...[
        SizedBox(height: 236, child: _AuctionCard(item: a, onTap: () => go('detail', it: a))),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 4),
      _pill(context, 'Plus', app.tr('أضف مزاداً', 'مزایدە زیاد بکە', 'Add an auction'), () => go('add'), filled: true),
    ];
  }

  Widget _empty(BuildContext context, String t) => Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        alignment: Alignment.center,
        child: Text(t, style: ts(context, 13, color: context.pal.muted)),
      );

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

  // ------------------------------------------------------------- my listings
  List<Widget> _mine(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final mine = app.marketItems.where((m) => m.mine && m.status != 'removed').toList();
    return [
      const SizedBox(height: 4),
      Text(app.tr('معروضاتي', 'بەرهەمەکانم', 'My listings'), style: ts(context, 26, weight: w700, height: 1.25)),
      Text(
        app.tr('ما تضيفه يظهر للمختبرات بعد موافقة إدارة LabGo.', 'دوای پەسەندکردنی LabGo دەردەکەوێت.', 'What you add shows to other labs once LabGo approves it.'),
        style: ts(context, 13, color: pal.muted),
      ),
      const SizedBox(height: 12),
      for (final m in mine) ...[_ListingCard(item: m, onTap: () => go('detail', it: m), showStatus: true), const SizedBox(height: 12)],
      if (mine.isEmpty) _empty(context, app.tr('لم تضف شيئاً بعد', 'هێشتا هیچت زیاد نەکردووە', 'Nothing added yet')),
      Tap(
        onTap: () => go('add'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: pal.accent, borderRadius: BorderRadius.circular(999)),
          child: Text(app.tr('+ إضافة', '+ زیادکردن', '+ Add'), style: ts(context, 15, weight: w700, color: Colors.white)),
        ),
      ),
    ];
  }

  // ------------------------------------------------------------ checkout
  List<Widget> _checkout(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final p = item!;
    if (_address.text.isEmpty) _address.text = app.labAddress;
    if (_phone.text.isEmpty) _phone.text = app.labPhone;
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
    final maxQty = p.stock > 0 ? p.stock : 99;
    return [
      const SizedBox(height: 4),
      Text(app.tr('إتمام الطلب', 'تەواوکردنی داواکاری', 'Checkout'), style: ts(context, 26, weight: w700, height: 1.25)),
      const SizedBox(height: 12),
      CardBox(
        child: Column(
          children: [
            Row(
              children: [
                _Thumb(item: p, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title, style: ts(context, 16, weight: w700)),
                      if (p.code.isNotEmpty) Text(p.code, style: ts(context, 12, color: pal.muted)),
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
                  round('+', true, () => setState(() => qty = qty < maxQty ? qty + 1 : maxQty)),
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
            const SizedBox(height: 10),
            Text(app.tr('رقم الهاتف', 'ژمارەی تەلەفۆن', 'Phone Number'), style: ts(context, 12, weight: w700, color: pal.muted)),
            const SizedBox(height: 4),
            BoxField(controller: _phone, ltr: true, keyboard: TextInputType.phone),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Tap(
        onTap: () async {
          if (_address.text.trim().isEmpty || _phone.text.trim().isEmpty) {
            app.toast(app.tr('أكمل العنوان ورقم الهاتف', 'ناونیشان و ژمارە پڕ بکەرەوە', 'Fill in the address and phone'));
            return;
          }
          final ok = await app.placeStoreOrder(p, quantity: qty, address: _address.text.trim(), phone: _phone.text.trim());
          if (ok && mounted) go('orders');
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
    String label(String st) => switch (st) {
          'preparing' => app.tr('قيد التجهيز', 'ئامادەکردن', 'Preparing'),
          'shipped' => app.tr('تم الشحن', 'نێردرا', 'Shipped'),
          'delivered' => app.tr('تم التوصيل', 'گەیەندرا', 'Delivered'),
          'cancelled' => app.tr('ملغي', 'هەڵوەشێنرایەوە', 'Cancelled'),
          _ => app.tr('جديد', 'نوێ', 'New'),
        };
    String act(String st) => switch (st) {
          'preparing' => app.tr('بدء التجهيز', 'دەستپێکردن', 'Start preparing'),
          'shipped' => app.tr('تم الشحن', 'نێردرا', 'Mark shipped'),
          'delivered' => app.tr('تم التوصيل', 'گەیەندرا', 'Mark delivered'),
          _ => app.tr('إلغاء', 'هەڵوەشاندنەوە', 'Cancel'),
        };
    // The seller moves an order forward; the buyer can only cancel a new one.
    List<String> next(StoreOrder o) => o.role == 'seller'
        ? switch (o.status) { 'new' => ['preparing', 'cancelled'], 'preparing' => ['shipped', 'cancelled'], 'shipped' => ['delivered'], _ => <String>[] }
        : (o.status == 'new' ? ['cancelled'] : <String>[]);
    Widget card(StoreOrder o) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${o.orderNo > 0 ? '#${o.orderNo}  ' : ''}${o.productName}', style: ts(context, 15, weight: w700))),
                    _Badge(label(o.status), o.status == 'cancelled' ? pal.muted : pal.accent, o.status == 'cancelled' ? pal.chipBg : pal.softAccent),
                  ],
                ),
                if (o.otherLab.isNotEmpty)
                  Text('${o.role == 'seller' ? app.tr('المشتري', 'کڕیار', 'Buyer') : app.tr('البائع', 'فرۆشیار', 'Seller')}: ${o.otherLab}', style: ts(context, 12, color: pal.muted)),
                Text(
                  '${o.kind == 'interest' ? app.tr('طلب شراء مختبر', 'داواکاری کڕینی تاقیگە', 'Lab purchase request') : '${app.tr('الكمية', 'بڕ', 'Qty')}: ${o.quantity}'}${o.createdAt.isEmpty ? '' : ' • ${o.createdAt}'}',
                  style: ts(context, 12, color: pal.muted),
                ),
                if (o.role == 'seller') Text('${o.phone}${o.address.isEmpty ? '' : ' • ${o.address}'}', style: ts(context, 12, color: pal.muted)),
                Text('${money(o.total)} IQD', style: ts(context, 14, weight: w700)),
                if (next(o).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final st in next(o))
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: Tap(
                            onTap: () => app.moveStoreOrder(o, st),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: st == 'cancelled' ? pal.chipBg : pal.accent,
                                borderRadius: BorderRadius.circular(999),
                                border: st == 'cancelled' ? Border.all(color: pal.cardBorder) : null,
                              ),
                              child: Text(act(st), style: ts(context, 12.5, weight: w700, color: st == 'cancelled' ? const Color(0xFFC81E1E) : Colors.white)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
    return [
      const SizedBox(height: 4),
      Text(app.tr('طلباتي', 'داواکارییەکانم', 'My Orders'), style: ts(context, 26, weight: w700, height: 1.25)),
      const SizedBox(height: 12),
      if (app.storeIncoming.isNotEmpty) ...[
        _sectionTitle(context, app.tr('طلبات واردة لي', 'داواکارییە هاتووەکان', 'Orders I received'), app.storeIncoming.length),
        const SizedBox(height: 8),
        for (final o in app.storeIncoming) card(o),
        const SizedBox(height: 6),
        _sectionTitle(context, app.tr('مشترياتي', 'کڕینەکانم', 'My purchases'), app.storeOrders.length),
        const SizedBox(height: 8),
      ],
      for (final o in app.storeOrders) card(o),
      if (app.storeOrders.isEmpty && app.storeIncoming.isEmpty) _empty(context, app.tr('لا توجد طلبات بعد', 'هێشتا داواکاری نییە', 'No orders yet')),
    ];
  }
}

// ---------------------------------------------------------------------------
// Pieces

class _Badge extends StatelessWidget {
  final String text;
  final Color fg, bg;
  const _Badge(this.text, this.fg, this.bg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: ts(context, 11, weight: w700, color: fg, height: 1.45)),
      );
}

String kindLabel(AppState app, String k) => switch (k) {
      'auction' => app.tr('مزاد', 'مزایدە', 'Auction'),
      'lab_sale' => app.tr('مختبر للبيع', 'تاقیگە بۆ فرۆشتن', 'Lab for sale'),
      'lab_auction' => app.tr('مختبر في المزاد', 'تاقیگە لە مزایدە', 'Lab auction'),
      _ => app.tr('منتج', 'بەرهەم', 'Product'),
    };

Widget statusBadge(BuildContext context, MarketItem m) {
  final app = context.app;
  final pal = app.palette;
  return switch (m.approvalStatus) {
    'approved' => _Badge(app.tr('معروض', 'بڵاوکراوە', 'Live'), pal.greenText, pal.softGreen),
    'rejected' => _Badge(app.tr('مرفوض', 'ڕەتکرایەوە', 'Rejected'), const Color(0xFFC81E1E), const Color(0xFFFDECEC)),
    _ => _Badge(app.tr('بانتظار موافقة LabGo', 'چاوەڕێی LabGo', 'Awaiting LabGo review'), pal.accent, pal.softAccent),
  };
}

/// First photo of a listing (network or local), or an icon.
class _Thumb extends StatelessWidget {
  final MarketItem item;
  final double size;
  final double? height;
  final double radius;
  const _Thumb({required this.item, this.size = 56, this.height, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    Widget child;
    if (item.localImages.isNotEmpty) {
      child = Image.memory(item.localImages.first, fit: BoxFit.cover);
    } else if (item.images.isNotEmpty) {
      child = Image.network(item.images.first, fit: BoxFit.cover, errorBuilder: (_, _, _) => _icon(pal));
    } else {
      child = _icon(pal);
    }
    return Container(
      width: size,
      height: height ?? size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(radius)),
      child: child,
    );
  }

  Widget _icon(dynamic pal) => Center(
        child: LIcon(item.isLab ? 'Building2' : item.category == 'Reagent' ? 'FlaskConical' : item.category == 'Consumable' ? 'TestTube' : 'Microscope', size: 26, color: pal.accent),
      );
}

class _ListingCard extends StatelessWidget {
  final MarketItem item;
  final VoidCallback onTap;
  final bool showStatus;
  const _ListingCard({required this.item, required this.onTap, this.showStatus = false});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final m = item;
    return Tap(
      onTap: onTap,
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
            Stack(
              children: [
                _Thumb(item: m, size: double.infinity, height: 160, radius: 0),
                PositionedDirectional(top: 10, start: 10, child: _Badge(kindLabel(app, m.kind), Colors.white, Colors.black.withValues(alpha: .6))),
                if (m.approved) PositionedDirectional(top: 8, end: 8, child: _ShareButton(item: m)),
                if (m.images.length + m.localImages.length > 1)
                  PositionedDirectional(
                    bottom: 10,
                    end: 10,
                    child: _Badge('${m.images.length + m.localImages.length} ${app.tr('صور', 'وێنە', 'photos')}', const Color(0xFF111111), Colors.white.withValues(alpha: .9)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(m.title, style: ts(context, 15, weight: w700))),
                      if (showStatus) statusBadge(context, m),
                      if (!showStatus && m.condition.isNotEmpty)
                        _Badge(m.condition == 'New' ? app.d('newC') : app.d('used'), m.condition == 'New' ? pal.greenText : const Color(0xFF8A5A00),
                            m.condition == 'New' ? pal.softGreen : const Color(0xFFFFF4D6)),
                    ],
                  ),
                  if (m.isLab && m.location.isNotEmpty) Text('${m.location}${m.area.isEmpty ? '' : ' • ${m.area}'}', style: ts(context, 12, color: pal.muted)),
                  if (m.description.isNotEmpty) Text(m.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(context, 12, color: pal.muted, height: 1.4)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.isAuction ? '${app.tr('أعلى مزايدة', 'بەرزترین', 'Top bid')}: ${money(m.currentBid > 0 ? m.currentBid : m.price)} IQD' : '${money(m.price)} IQD',
                          style: ts(context, 15, weight: w700),
                        ),
                      ),
                      if (m.labName.isNotEmpty && !m.mine) Text(m.labName, style: ts(context, 11, color: pal.muted)),
                      if (m.kind == 'product' && m.stock > 0) Text('  ${app.tr('المخزون', 'کۆگا', 'Stock')}: ${m.stock}', style: ts(context, 11, color: pal.muted)),
                    ],
                  ),
                  if (showStatus && m.approvalStatus == 'rejected' && m.rejectReason.isNotEmpty)
                    Text('${app.tr('السبب', 'هۆکار', 'Reason')}: ${m.rejectReason}', style: ts(context, 12, color: const Color(0xFFC81E1E))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small auction card with its countdown ring.
class _AuctionCard extends StatelessWidget {
  final MarketItem item;
  final VoidCallback onTap;
  const _AuctionCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    return Tap(
      onTap: onTap,
      scale: .98,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: pal.cardBorder)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                _Thumb(item: item, size: double.infinity, height: 130, radius: 0),
                PositionedDirectional(top: 8, end: 8, child: CountdownRing(item: item, size: 50, dark: true)),
                if (item.approved) PositionedDirectional(top: 8, start: 8, child: _ShareButton(item: item)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(context, 14, weight: w700)),
                  Text('${money(item.currentBid > 0 ? item.currentBid : item.price)} IQD', style: ts(context, 15, weight: w900, color: pal.accent)),
                  Text('${item.bids} ${app.tr('مزايدات', 'مزایدە', 'bids')}${item.isLab ? ' • ${app.tr('مختبر', 'تاقیگە', 'Lab')}' : ''}', style: ts(context, 11, color: pal.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A ring that empties as the auction runs out, ticking every second.
class CountdownRing extends StatefulWidget {
  final MarketItem item;
  final double size;
  final bool dark;
  const CountdownRing({super.key, required this.item, this.size = 120, this.dark = false});

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final m = widget.item;
    final end = m.endsAt;
    final start = m.startedAt ?? (end?.subtract(Duration(days: m.durationDays)));
    final now = DateTime.now();
    final left = end == null ? Duration.zero : end.difference(now);
    final total = (end != null && start != null) ? end.difference(start).inSeconds : 1;
    final frac = end == null ? 1.0 : (left.inSeconds / (total <= 0 ? 1 : total)).clamp(0.0, 1.0);
    final ended = end != null && left.isNegative;
    String label;
    if (end == null) {
      label = app.tr('يبدأ بعد الموافقة', 'دوای پەسەند', 'Starts on approval');
    } else if (ended) {
      label = app.tr('انتهى', 'کۆتایی هات', 'Ended');
    } else if (left.inDays > 0) {
      label = '${left.inDays}${app.tr('ي', 'ڕ', 'd')} ${left.inHours % 24}${app.tr('س', 'ک', 'h')}';
    } else {
      String two(int v) => v.toString().padLeft(2, '0');
      label = '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    }
    final small = widget.size < 80;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: widget.dark ? BoxDecoration(color: Colors.black.withValues(alpha: .55), shape: BoxShape.circle) : null,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: frac),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOut,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v, widget.dark ? Colors.white24 : pal.track, ended ? pal.muted : pal.accent, small ? 4 : 9),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(small ? 6 : 14),
              child: FittedBox(
                child: Text(label, textAlign: TextAlign.center, textDirection: TextDirection.ltr,
                    style: ts(context, small ? 11 : 18, weight: w900, color: widget.dark ? Colors.white : pal.ink, height: 1.1)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color track, color;
  final double stroke;
  _RingPainter(this.value, this.track, this.color, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - stroke / 2 - 1;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, p..color = track);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * value, false, p..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.value != value || o.color != color || o.track != track;
}

// ---------------------------------------------------------------------------
// Detail page: photos, details; buy, bid or contact.

class _Detail extends StatefulWidget {
  final MarketItem item;
  final VoidCallback onBuy;
  const _Detail({required this.item, required this.onBuy});

  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  int page = 0;
  final _bid = TextEditingController();

  @override
  void dispose() {
    _bid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final m = widget.item;
    final photos = <Widget>[
      for (final b in m.localImages) Image.memory(b, fit: BoxFit.cover),
      for (final u in m.images) Image.network(u, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
    ];
    Widget row(String k, String v) => v.trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 110, child: Text(k, style: ts(context, 13, color: pal.muted))),
                Expanded(child: Text(v, style: ts(context, 14, weight: w600))),
              ],
            ),
          );
    final ended = m.endsAt != null && m.endsAt!.isBefore(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        // photo gallery
        Container(
          height: 260,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(24)),
          child: photos.isEmpty
              ? _Thumb(item: m, size: double.infinity, height: 260, radius: 24)
              : Stack(
                  children: [
                    PageView(onPageChanged: (i) => setState(() => page = i), children: photos),
                    if (photos.length > 1)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < photos.length; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: page == i ? 18 : 7,
                                height: 7,
                                decoration: BoxDecoration(color: page == i ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(9)),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Badge(kindLabel(app, m.kind), pal.accent, pal.softAccent),
            const SizedBox(width: 6),
            if (m.mine) statusBadge(context, m),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(m.title, style: ts(context, 24, weight: w700, height: 1.25))),
            if (m.approved) ...[const SizedBox(width: 8), _ShareButton(item: m)],
          ],
        ),
        if (m.labName.isNotEmpty) Text(m.labName, style: ts(context, 13, color: pal.muted)),
        const SizedBox(height: 10),
        if (m.isAuction)
          CardBox(
            child: Row(
              children: [
                CountdownRing(item: m, size: 110),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.tr('أعلى مزايدة', 'بەرزترین مزایدە', 'Current bid'), style: ts(context, 12, weight: w700, color: pal.muted)),
                      Text('${money(m.currentBid > 0 ? m.currentBid : m.price)} IQD', style: ts(context, 22, weight: w900, color: pal.accent)),
                      Text('${m.bids} ${app.tr('مزايدات', 'مزایدە', 'bids')} • ${app.tr('يبدأ من', 'دەستپێک', 'Starts at')} ${money(m.price)}', style: ts(context, 12, color: pal.muted)),
                      if (m.youLead) Text(app.tr('أنت صاحب أعلى مزايدة', 'تۆ بەرزترینیت', 'You have the top bid'), style: ts(context, 12, weight: w700, color: pal.greenText)),
                      if (m.won) Text(app.tr('🎉 ربحت هذا المزاد', '🎉 بردتەوە', '🎉 You won this auction'), style: ts(context, 13, weight: w900, color: pal.greenText)),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Text('${money(m.price)} IQD', style: ts(context, 22, weight: w900, color: pal.accent)),
        const SizedBox(height: 12),
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row(app.tr('الفئة', 'پۆل', 'Category'), switch (m.category) {
                'Device' => app.tr('جهاز', 'ئامێر', 'Device'),
                'Reagent' => app.tr('كاشف', 'کاشف', 'Reagent'),
                'Consumable' => app.tr('مستهلك', 'بەکاربراو', 'Consumable'),
                _ => m.category,
              }),
              row(app.tr('الحالة', 'دۆخ', 'Condition'), m.condition == 'New' ? app.d('newC') : m.condition == 'Used' ? app.d('used') : ''),
              row(app.tr('الكود', 'کۆد', 'Code'), m.code),
              row(app.tr('المخزون', 'کۆگا', 'Stock'), m.kind == 'product' && m.stock > 0 ? '${m.stock} ${m.unit}' : ''),
              row(app.tr('الموقع', 'شوێن', 'Location'), m.location),
              row(app.tr('المساحة', 'ڕووبەر', 'Area'), m.area),
              row(app.tr('الأجهزة', 'ئامێرەکان', 'Equipment'), m.equipment),
              if (m.description.isNotEmpty) ...[
                Text(app.tr('الوصف', 'وەسف', 'Description'), style: ts(context, 13, color: pal.muted)),
                const SizedBox(height: 4),
                Text(m.description, style: ts(context, 14, height: 1.6)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!m.mine && m.approved && m.isAuction && !ended) ...[
          Row(
            children: [
              Expanded(
                child: BoxField(
                  controller: _bid,
                  hint: '${app.tr('أكثر من', 'زیاتر لە', 'More than')} ${money(m.currentBid > 0 ? m.currentBid : m.price)}',
                  keyboard: TextInputType.number,
                  ltr: true,
                ),
              ),
              const SizedBox(width: 8),
              Tap(
                onTap: () async {
                  final v = int.tryParse(_bid.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                  if (v <= (m.currentBid > 0 ? m.currentBid : m.price)) {
                    app.toast(app.tr('المزايدة يجب أن تكون أعلى من الحالية', 'دەبێت بەرزتر بێت', 'Your bid must be higher than the current one'));
                    return;
                  }
                  final r = await app.placeBid(m, v);
                  if (r != null) _bid.clear();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(color: pal.accent, borderRadius: BorderRadius.circular(999)),
                  child: Text(app.tr('زايد', 'مزایدە', 'Bid'), style: ts(context, 15, weight: w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ] else if (!m.mine && m.approved && m.kind == 'product')
          Tap(
            onTap: widget.onBuy,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: pal.accent, borderRadius: BorderRadius.circular(999)),
              child: Text(app.tr('شراء', 'کڕین', 'Buy'), style: ts(context, 16, weight: w700, color: Colors.white)),
            ),
          )
        else if (!m.mine && m.approved && m.kind == 'lab_sale')
          Tap(
            onTap: () => app.placeStoreOrder(m, phone: app.labPhone),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: pal.accent, borderRadius: BorderRadius.circular(999)),
              child: Text(app.tr('أنا مهتم بالشراء', 'حەزم لێیەتی', "I'm interested"), style: ts(context, 16, weight: w700, color: Colors.white)),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add: product, auction (device), lab for sale, lab auction — with photos.

class _AddListing extends StatefulWidget {
  final VoidCallback onDone;
  const _AddListing({required this.onDone});

  @override
  State<_AddListing> createState() => _AddListingState();
}

class _AddListingState extends State<_AddListing> {
  String kind = 'product';
  String category = 'Device';
  String condition = 'New';
  String unit = 'piece';
  int days = 3;
  final List<Uint8List> images = [];
  bool saving = false;
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _code = TextEditingController();
  final _stock = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  final _area = TextEditingController();
  final _equipment = TextEditingController();

  @override
  void dispose() {
    for (final c in [_title, _price, _code, _stock, _desc, _location, _area, _equipment]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final isLab = kind == 'lab_sale' || kind == 'lab_auction';
    final isAuction = kind == 'auction' || kind == 'lab_auction';
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(t, style: ts(context, 12, weight: w700, color: pal.muted)),
        );
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
                      child: Text(o.$2, style: ts(context, 12.5, weight: w700, color: value == o.$1 ? pal.appBg : pal.muted2)),
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
          Text(app.tr('ماذا تريد أن تعرض؟', 'چی دەخەیتە ڕوو؟', 'What do you want to list?'), style: ts(context, 15, weight: w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in const ['product', 'auction', 'lab_sale', 'lab_auction'])
                FilterChipPill(label: kindLabel(app, k), selected: kind == k, onTap: () => setState(() => kind = k)),
            ],
          ),
          label(app.tr('الصور (حتى 6)', 'وێنە (تا 6)', 'Photos (up to 6)')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < images.length; i++)
                Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(images[i], width: 76, height: 76, fit: BoxFit.cover)),
                  PositionedDirectional(
                    top: 2,
                    end: 2,
                    child: Tap(
                      onTap: () => setState(() => images.removeAt(i)),
                      child: Container(width: 22, height: 22, alignment: Alignment.center, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const LIcon('X', size: 12, color: Colors.white)),
                    ),
                  ),
                ]),
              if (images.length < 6)
                Tap(
                  onTap: () async {
                    final picked = await app.pickImages(max: 6 - images.length);
                    if (picked.isNotEmpty) setState(() => images.addAll(picked));
                  },
                  child: Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: pal.chipBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: pal.line)),
                    child: LIcon('ImagePlus', size: 24, color: pal.accent),
                  ),
                ),
            ],
          ),
          label(isLab ? app.tr('اسم المختبر', 'ناوی تاقیگە', 'Lab name') : app.d('productName')),
          BoxField(controller: _title),
          label(isAuction ? app.tr('سعر البداية (د.ع)', 'نرخی دەستپێک', 'Starting bid (IQD)') : app.d('productPrice')),
          BoxField(controller: _price, keyboard: TextInputType.number, ltr: true),
          if (isAuction) ...[
            label(app.tr('مدة المزاد', 'ماوەی مزایدە', 'Auction length')),
            seg([('1', app.tr('يوم', 'ڕۆژ', '1 day')), ('3', app.tr('3 أيام', '3 ڕۆژ', '3 days')), ('7', app.tr('أسبوع', 'هەفتە', '1 week')), ('14', app.tr('أسبوعان', '2 هەفتە', '2 weeks'))], '$days', (v) => days = int.parse(v)),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(app.tr('يبدأ العدّاد عند موافقة إدارة LabGo', 'دوای پەسەندکردن دەست پێدەکات', 'The countdown starts when LabGo approves it'), style: ts(context, 11, color: pal.muted)),
            ),
          ],
          if (!isLab) ...[
            label(app.d('category')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in const [('Device', 'جهاز', 'ئامێر', 'Device'), ('Reagent', 'كاشف', 'کاشف', 'Reagent'), ('Consumable', 'مستهلك', 'بەکاربراو', 'Consumable')])
                FilterChipPill(label: app.tr(c.$2, c.$3, c.$4), selected: category == c.$1, onTap: () => setState(() => category = c.$1)),
            ]),
            label(app.d('condition')),
            seg([('New', app.d('newC')), ('Used', app.d('used'))], condition, (v) => condition = v),
          ],
          if (kind == 'product') ...[
            label(app.tr('الكمية (المخزون)', 'بڕ', 'Quantity (stock)')),
            Row(
              children: [
                Expanded(child: BoxField(controller: _stock, keyboard: TextInputType.number, ltr: true)),
                const SizedBox(width: 8),
                Expanded(
                  child: seg([('piece', app.tr('قطعة', 'پارچە', 'piece')), ('box', app.tr('علبة', 'قوتوو', 'box')), ('carton', app.tr('كرتون', 'کارتۆن', 'carton'))], unit, (v) => unit = v),
                ),
              ],
            ),
            label(app.tr('كود المنتج (اختياري)', 'کۆد (ئارەزوومەندانە)', 'Product code (optional)')),
            BoxField(controller: _code, ltr: true),
          ],
          if (isLab) ...[
            label(app.tr('الموقع', 'شوێن', 'Location')),
            BoxField(controller: _location),
            label(app.tr('المساحة', 'ڕووبەر', 'Area')),
            BoxField(controller: _area),
            label(app.tr('الأجهزة المتوفرة', 'ئامێرەکان', 'Equipment included')),
            BoxField(controller: _equipment, lines: 2, fontSize: 14),
          ],
          label(app.d('description')),
          BoxField(controller: _desc, lines: 3, fontSize: 14),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: pal.softAccent, borderRadius: BorderRadius.circular(14)),
            child: Text(
              app.tr('سيظهر للمختبرات بعد مراجعته وموافقة إدارة LabGo.', 'دوای پەسەندکردنی LabGo دەردەکەوێت.', 'It will show to other labs after LabGo reviews and approves it.'),
              style: ts(context, 12, weight: w600, color: pal.accent),
            ),
          ),
          const SizedBox(height: 12),
          Tap(
            onTap: () async {
              if (saving) return;
              final title = _title.text.trim();
              final price = int.tryParse(_price.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              final stock = int.tryParse(_stock.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              if (title.isEmpty || price <= 0 || (kind == 'product' && stock <= 0)) {
                app.toast(app.tr('أكمل الاسم والسعر${kind == 'product' ? ' والكمية' : ''}', 'ناو و نرخ پڕ بکەرەوە', 'Fill in the name and price${kind == 'product' ? ' and quantity' : ''}'));
                return;
              }
              setState(() => saving = true);
              final ok = await app.addListing(
                MarketItem(
                  kind: kind,
                  title: title,
                  price: price,
                  description: _desc.text.trim(),
                  category: isLab ? '' : category,
                  condition: isLab ? '' : condition,
                  code: _code.text.trim(),
                  stock: kind == 'product' ? stock : 0,
                  unit: kind == 'product' ? unit : '',
                  location: _location.text.trim(),
                  area: _area.text.trim(),
                  equipment: _equipment.text.trim(),
                  durationDays: days,
                ),
                List.of(images),
              );
              if (!mounted) return;
              setState(() => saving = false);
              if (ok) {
                app.toast(app.tr('تم الإرسال للمراجعة ✓', 'نێردرا بۆ پەسەندکردن ✓', 'Sent for review ✓'));
                widget.onDone();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: pal.accent, borderRadius: BorderRadius.circular(999)),
              child: Text(saving ? '…' : app.tr('إرسال للمراجعة', 'ناردن بۆ پەسەندکردن', 'Send for review'), style: ts(context, 15, weight: w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}


/// One built-in banner slide: title, line, button and what the button does.
class _Slide {
  final String title, sub, cta, icon;
  final Color color;
  final VoidCallback onTap;
  const _Slide(this.title, this.sub, this.cta, this.icon, this.color, this.onTap);
}

/// The store's banner: slides uploaded by the LabGo admin, changing on a
/// timer. With none uploaded yet, the built-in [fallback] slides show instead.
class _StoreBanner extends StatefulWidget {
  final List<String> images;
  final List<_Slide> fallback;
  final int seconds;
  final void Function(int index) onTapImage;
  const _StoreBanner({required this.images, required this.seconds, required this.fallback, required this.onTapImage});

  @override
  State<_StoreBanner> createState() => _StoreBannerState();
}

class _StoreBannerState extends State<_StoreBanner> {
  final _page = PageController();
  Timer? _timer;
  int at = 0;

  int get _count => widget.images.isNotEmpty ? widget.images.length : widget.fallback.length;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: widget.seconds), (_) {
      if (!mounted || _count < 2 || !_page.hasClients) return;
      _page.animateToPage((at + 1) % _count, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  void didUpdateWidget(_StoreBanner old) {
    super.didUpdateWidget(old);
    // Admin banners arrived (or were removed): start again from the first slide.
    if (old.images.isEmpty != widget.images.isEmpty && _page.hasClients) {
      at = 0;
      _page.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  Widget _text(BuildContext context, _Slide s) => Container(
        color: s.color,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(context, 18, weight: w900, color: Colors.white, height: 1.25)),
                  const SizedBox(height: 4),
                  Text(s.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(context, 12.5, color: Colors.white.withValues(alpha: .9), height: 1.4)),
                  const SizedBox(height: 10),
                  Tap(
                    onTap: s.onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                      child: Text(s.cta, style: ts(context, 12.5, weight: w700, color: const Color(0xFF111111))),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(16)),
              child: LIcon(s.icon, size: 40, color: Colors.white),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final custom = widget.images.isNotEmpty;
    final rtl = Directionality.of(context);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 5 / 2,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: PageView.builder(
                controller: _page,
                itemCount: _count,
                onPageChanged: (i) => setState(() => at = i),
                itemBuilder: (_, i) => custom
                    ? GestureDetector(
                        onTap: () => widget.onTapImage(i),
                        child: Image.network(
                          widget.images[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(color: pal.chipBg, child: Center(child: LIcon('ImagePlus', size: 28, color: pal.muted))),
                          loadingBuilder: (_, child, p) => p == null ? child : ColoredBox(color: pal.chipBg),
                        ),
                      )
                    : GestureDetector(
                        onTap: widget.fallback[i].onTap,
                        child: Directionality(textDirection: rtl, child: _text(context, widget.fallback[i])),
                      ),
              ),
            ),
          ),
        ),
        if (_count > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: at == i ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: at == i ? pal.accent : pal.track, borderRadius: BorderRadius.circular(999)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}


/// Round share button on a listing: copies its share link.
class _ShareButton extends StatelessWidget {
  final MarketItem item;
  const _ShareButton({required this.item});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return Tap(
      onTap: () => app.shareListing(item),
      scale: .9,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))]),
        child: const LIcon('Share2', size: 16, color: Color(0xFF111111)),
      ),
    );
  }
}
