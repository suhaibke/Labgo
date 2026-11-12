import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/quick_service.dart';

/// Horizontally scrollable row of admin-managed quick-service shortcuts
/// (e.g. "Vitamin D"), with a header above it, matching the reference
/// design.
class QuickServicesRow extends StatelessWidget {
  final List<QuickService> services;
  final String languageCode;
  final ValueChanged<QuickService> onTap;
  final VoidCallback? onViewAll;

  const QuickServicesRow({
    super.key,
    required this.services,
    required this.languageCode,
    required this.onTap,
    this.onViewAll,
  });

  static const _palette = [
    _ServiceColors(bg: Color(0xFFEEEDFE), fg: Color(0xFF3C3489)),
    _ServiceColors(bg: Color(0xFFE1F5EE), fg: Color(0xFF085041)),
    _ServiceColors(bg: Color(0xFFFAECE7), fg: Color(0xFF712B13)),
    _ServiceColors(bg: Color(0xFFFBEAF0), fg: Color(0xFF72243E)),
  ];

  @override
  Widget build(BuildContext context) {
    final isEmpty = services.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'خدمات سريعة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (!isEmpty && onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: const Text(
                    'عرض الكل',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7257D8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F4FD),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text(
                'لا توجد خدمات سريعة حالياً',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF9C9AA8)),
              ),
            )
          else
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: services.length,
                separatorBuilder: (context, index) => const SizedBox(width: 18),
                itemBuilder: (context, index) {
                  final service = services[index];
                  final colors = _palette[index % _palette.length];
                  return _ServiceCard(
                    service: service,
                    colors: colors,
                    languageCode: languageCode,
                    onTap: () => onTap(service),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceColors {
  final Color bg;
  final Color fg;

  const _ServiceColors({required this.bg, required this.fg});
}

class _ServiceCard extends StatelessWidget {
  final QuickService service;
  final _ServiceColors colors;
  final String languageCode;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
    required this.colors,
    required this.languageCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = service.displayName(languageCode);
    final englishName = service.name.trim();
    final showEnglishName = englishName.isNotEmpty && englishName != title;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 136,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: service.icon,
                fit: BoxFit.cover,
                memCacheWidth: (52 * MediaQuery.devicePixelRatioOf(context)).round(),
                memCacheHeight: (52 * MediaQuery.devicePixelRatioOf(context)).round(),
                errorWidget: (context, url, error) => Icon(
                  Icons.science_outlined,
                  color: colors.fg,
                  size: 22,
                ),
                placeholder: (context, url) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF201B37),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (showEnglishName) ...[
              const SizedBox(height: 3),
              Text(
                englishName,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF9C9AA8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
