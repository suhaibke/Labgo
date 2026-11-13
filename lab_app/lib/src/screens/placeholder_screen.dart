import 'package:flutter/material.dart';

import '../ui.dart';

/// Temporary screen for tabs that are not converted yet (Add, Send, Settings).
class PlaceholderScreen extends StatelessWidget {
  final String tab;
  const PlaceholderScreen({super.key, required this.tab});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final pal = app.palette;
    final title = tab == 'add'
        ? app.tr('إضافة مريض', 'زیادکردنی نەخۆش', 'Add Patient')
        : tab == 'send'
        ? app.tr(
            'إرسال لمختبرات أخرى',
            'ناردن بۆ تاقیگەکانی تر',
            'Send to Other Labs',
          )
        : app.w('settings');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        112 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: ts(context, 28, weight: w700)),
          const SizedBox(height: 12),
          CardBox(
            child: Text(
              app.tr(
                'هذه الشاشة قيد التحويل وستضاف في الدفعة القادمة.',
                'ئەم شاشەیە لە دۆخی گۆڕیندایە.',
                'This screen is being converted and will arrive in the next batch.',
              ),
              style: ts(context, 14, color: pal.muted),
            ),
          ),
          if (tab == 'profile') ...[
            const SizedBox(height: 12),
            Tap(
              onTap: () => app.showLogout(true),
              child: CardBox(
                child: Row(
                  children: [
                    LIcon('LogOut', size: 18, color: pal.accent),
                    const SizedBox(width: 12),
                    Text(app.w('logout'), style: ts(context, 15, weight: w700)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
