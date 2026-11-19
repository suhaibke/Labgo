import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';

/// A lab result opened from the link the lab sent (WhatsApp / SMS / QR code).
/// The link itself is the key, so it works without signing in.
class ResultLinkScreen extends StatefulWidget {
  final String code;
  const ResultLinkScreen({super.key, required this.code});

  @override
  State<ResultLinkScreen> createState() => _ResultLinkScreenState();
}

class _ResultLinkScreenState extends State<ResultLinkScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  String get _base => ApiService.baseUrl.replaceAll(RegExp(r'/+$'), '');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(Uri.parse('$_base/r/${widget.code}/data')).timeout(const Duration(seconds: 20));
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && json['success'] == true) {
        _data = Map<String, dynamic>.from(json['data'] as Map);
      } else {
        _error = 'الرابط غير صالح';
      }
    } catch (_) {
      _error = 'تعذر تحميل النتيجة، تحقق من الاتصال';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openPdf() async {
    final ok = await launchUrl(Uri.parse('$_base/r/${widget.code}?pdf=1'), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح التقرير')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _data;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null || d == null) {
      body = _Message(icon: Icons.link_off, title: _error ?? 'الرابط غير صالح', action: TextButton(onPressed: _load, child: const Text('إعادة المحاولة')));
    } else if (d['ready'] != true) {
      final lab = Map<String, dynamic>.from(d['lab'] as Map? ?? {});
      body = _Message(
        icon: Icons.science_outlined,
        title: 'نتيجتك قيد العمل',
        text: '${(lab['name'] ?? '').toString().isNotEmpty ? lab['name'] : 'المختبر'} يعمل على تحاليلك الآن، وستصلك رسالة عند جاهزيتها.',
        action: TextButton(onPressed: _load, child: const Text('تحديث')),
      );
    } else {
      final lab = Map<String, dynamic>.from(d['lab'] as Map? ?? {});
      final results = [for (final r in (d['results'] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
      final date = DateTime.tryParse('${d['date'] ?? ''}')?.toLocal();
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${lab['name'] ?? ''}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              [
                '${d['patient'] ?? ''}',
                'رقم الطلب ${d['code'] ?? ''}',
                if (date != null) '${date.year}/${date.month}/${date.day}',
              ].where((s) => s.trim().isNotEmpty).join(' • '),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 16),
            for (final r in results) _ResultTile(r: r),
            if ('${d['comment'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(child: Padding(padding: const EdgeInsets.all(12), child: Text('${d['comment']}'))),
            ],
            const SizedBox(height: 16),
            if ('${d['reportUrl'] ?? ''}'.isNotEmpty)
              FilledButton.icon(
                onPressed: _openPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('عرض التقرير PDF'),
              ),
          ],
        ),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(appBar: AppBar(title: const Text('نتيجة التحليل')), body: body),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Map<String, dynamic> r;
  const _ResultTile({required this.r});

  @override
  Widget build(BuildContext context) {
    final flag = '${r['flag'] ?? ''}';
    final color = flag == 'high'
        ? const Color(0xFFDC2626)
        : flag == 'low'
            ? const Color(0xFF2563EB)
            : flag == 'normal'
                ? const Color(0xFF16A34A)
                : null;
    const label = {'high': 'مرتفع', 'low': 'منخفض', 'normal': 'طبيعي'};
    return Card(
      child: ListTile(
        title: Text('${r['test'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: '${r['range'] ?? ''}'.isNotEmpty ? Text('المعدل الطبيعي: ${r['range']}', textDirection: TextDirection.rtl) : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${r['value'] ?? ''} ${r['unit'] ?? ''}'.trim(),
                textDirection: TextDirection.ltr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            if (label[flag] != null) Text(label[flag]!, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;
  const _Message({required this.icon, required this.title, this.text, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (text != null) ...[const SizedBox(height: 6), Text(text!, textAlign: TextAlign.center)],
            if (action != null) ...[const SizedBox(height: 8), action!],
          ]),
        ),
      );
}
