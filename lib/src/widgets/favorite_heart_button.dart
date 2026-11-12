import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import '../../l10n/app_localizations.dart';
import 'auth_required_dialog.dart';

/// Heart toggle that adds/removes a lab from the signed-in user's favorites.
///
/// Reads its initial state from [FavoritesService]'s cache, so lists paint
/// correctly without an extra request per card.
class FavoriteHeartButton extends StatefulWidget {
  final String labId;
  final double size;
  final Color? inactiveColor;

  /// Called after a successful toggle with the new state.
  final ValueChanged<bool>? onChanged;

  const FavoriteHeartButton({
    super.key,
    required this.labId,
    this.size = 20,
    this.inactiveColor,
    this.onChanged,
  });

  @override
  State<FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<FavoriteHeartButton> {
  late bool _isFavorite = FavoritesService.isFavorite(widget.labId);
  bool _busy = false;

  @override
  void didUpdateWidget(covariant FavoriteHeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labId != widget.labId) {
      _isFavorite = FavoritesService.isFavorite(widget.labId);
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;

    final l10n = AppLocalizations.of(context)!;

    if (AuthService.isGuestMode) {
      showAuthRequiredDialog(context, message: l10n.loginToUseFavorites);
      return;
    }

    setState(() {
      _busy = true;
      // Optimistic flip so the tap feels instant
      _isFavorite = !_isFavorite;
    });

    final result = await FavoritesService.toggle(widget.labId);
    if (!mounted) return;

    if (result['success'] == true) {
      final isFavorite = result['isFavorite'] == true;
      setState(() {
        _isFavorite = isFavorite;
        _busy = false;
      });
      widget.onChanged?.call(isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite ? l10n.addedToFavorites : l10n.removedFromFavorites,
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Roll the optimistic flip back
    setState(() {
      _isFavorite = !_isFavorite;
      _busy = false;
    });

    if (result['requiresLogin'] == true) {
      showAuthRequiredDialog(context, message: l10n.loginToUseFavorites);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _toggle,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          _isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          size: widget.size,
          color: _isFavorite
              ? AppTheme.error
              : (widget.inactiveColor ?? AppTheme.gray400),
        ),
      ),
    );
  }
}
