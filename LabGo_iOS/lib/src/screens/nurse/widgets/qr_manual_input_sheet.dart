import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// Bottom sheet widget for manual QR code input
/// Used as a backup when QR scanner is unavailable or fails
class QRManualInputSheet extends StatefulWidget {
  final Future<String> Function(String qrCode) onSubmit;

  const QRManualInputSheet({
    super.key,
    required this.onSubmit,
  });

  @override
  State<QRManualInputSheet> createState() => _QRManualInputSheetState();
}

class _QRManualInputSheetState extends State<QRManualInputSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the input field when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? _validateQRCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'error_required';
    }
    if (value.trim().length < 3) {
      return 'error_too_short';
    }
    if (value.trim().length > 50) {
      return 'error_too_long';
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    final l10n = AppLocalizations.of(context)!;
    final input = _controller.text.trim();

    // Validate input
    final error = _validateQRCode(input);
    if (error != null) {
      setState(() {
        _errorText = switch (error) {
          'error_required' => l10n.invalidQRCodeFormat,
          'error_too_short' => l10n.qrCodeTooShort,
          'error_too_long' => l10n.qrCodeTooLong,
          _ => l10n.invalidQRCodeFormat,
        };
      });
      // Shake animation for visual feedback
      setState(() {}); // Trigger rebuild
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final result = await widget.onSubmit(input);
      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorText = l10n.invalidQRCodeFormat;
        });
      }
    }
  }

  void _handleTextChanged(String value) {
    // Clear error as user types
    if (_errorText != null) {
      setState(() {
        _errorText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.keyboard_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.enterQRCodeTitle,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.enterQRCodeSubtitle,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppTheme.gray600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Text Field
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _handleTextChanged,
            onSubmitted: (_) => _handleSubmit(),
            enabled: !_isSubmitting,
            maxLength: 50,
            textCapitalization: TextCapitalization.none,
            keyboardType: TextInputType.text,
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: AppTheme.gray900,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: l10n.enterQRCodeHint,
              hintStyle: GoogleFonts.cairo(
                fontSize: 15,
                color: AppTheme.gray400,
              ),
              prefixIcon: const Icon(
                Icons.qr_code_2_rounded,
                color: AppTheme.gray500,
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: AppTheme.gray500,
                      ),
                      onPressed: () {
                        _controller.clear();
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        }
                      },
                    )
                  : null,
              errorText: _errorText,
              counterText: '${_controller.text.length}/50',
              counterStyle: GoogleFonts.cairo(
                fontSize: 12,
                color: AppTheme.gray500,
              ),
              filled: true,
              fillColor: AppTheme.gray50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _errorText != null
                      ? AppTheme.error
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _errorText != null
                      ? AppTheme.error
                      : AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.error,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.error,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              // Cancel Button
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: BorderSide(
                      color: AppTheme.gray300,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.cancel,
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Submit Button
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.gray300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          l10n.verify,
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
