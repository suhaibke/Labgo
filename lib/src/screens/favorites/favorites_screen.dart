import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../theme/app_theme.dart';
import '../../services/lab_service.dart';
import '../../services/favorites_service.dart';
import '../../widgets/favorite_heart_button.dart';
import '../lab_details/lab_details_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Labs the patient bookmarked with the heart icon.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Lab> _labs = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final result = await FavoritesService.getFavoriteLabs();
    if (!mounted) return;

    setState(() {
      _labs = (result['labs'] as List<Lab>?) ?? [];
      _hasError = result['success'] != true;
      _isLoading = false;
    });
  }

  void _onUnfavorited(String labId) {
    setState(() => _labs.removeWhere((lab) => lab.id == labId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      appBar: AppBar(
        title: Text(l10n.favorites),
        elevation: 0,
        backgroundColor: AppTheme.backgroundLavender,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: _load,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              )
            : (_labs.isEmpty ? _buildEmpty(l10n) : _buildList()),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              size: 36,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _hasError ? l10n.tryAgain : l10n.noFavoriteLabsYet,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _hasError ? '' : l10n.favoritesHint,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppTheme.gray600),
        ),
        if (_hasError) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _load,
              child: Text(l10n.retry),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _labs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final lab = _labs[index];
        return _FavoriteLabCard(
          lab: lab,
          onUnfavorited: () => _onUnfavorited(lab.id),
        );
      },
    );
  }
}

class _FavoriteLabCard extends StatelessWidget {
  final Lab lab;
  final VoidCallback onUnfavorited;

  const _FavoriteLabCard({required this.lab, required this.onUnfavorited});

  static const _iconBg = Color(0xFFEEEDFE);

  String _buildSubtitle() {
    final parts = <String>[];
    if (lab.city != null && lab.city!.isNotEmpty) parts.add(lab.city!);
    if (lab.address != null && lab.address!.isNotEmpty) parts.add(lab.address!);
    return parts.join(' - ');
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _buildSubtitle();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LabDetailsScreen(lab: lab),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Lab photo (right in RTL) - falls back to a flask icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                child: lab.hasValidLogo
                    ? CachedNetworkImage(
                        imageUrl: lab.logo!,
                        fit: BoxFit.cover,
                        width: 48,
                        height: 48,
                        errorWidget: (context, url, error) => const Icon(
                          TablerIcons.flask,
                          size: 22,
                          color: AppTheme.primaryColor,
                        ),
                        placeholder: (context, url) => const SizedBox.shrink(),
                      )
                    : const Icon(
                        TablerIcons.flask,
                        size: 22,
                        color: AppTheme.primaryColor,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lab.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gray900,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.gray600,
                        ),
                      ),
                    ],
                    if (lab.averageRating != null && lab.averageRating! > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFFFB020),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            lab.averageRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.gray700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              FavoriteHeartButton(
                labId: lab.id,
                onChanged: (isFavorite) {
                  if (!isFavorite) onUnfavorited();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
