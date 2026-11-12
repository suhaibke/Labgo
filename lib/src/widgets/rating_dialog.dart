import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../services/order_service.dart';

/// A beautiful rating dialog for rating labs and nurses after order completion
class RatingDialog extends StatefulWidget {
  final String orderId;
  final String labName;
  final bool hasNurse;
  final String? nurseName;
  final VoidCallback? onRatingSubmitted;

  const RatingDialog({
    super.key,
    required this.orderId,
    required this.labName,
    this.hasNurse = false,
    this.nurseName,
    this.onRatingSubmitted,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();

  /// Show the rating dialog
  static Future<void> show({
    required BuildContext context,
    required String orderId,
    required String labName,
    bool hasNurse = false,
    String? nurseName,
    VoidCallback? onRatingSubmitted,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingDialog(
        orderId: orderId,
        labName: labName,
        hasNurse: hasNurse,
        nurseName: nurseName,
        onRatingSubmitted: onRatingSubmitted,
      ),
    );
  }
}

class _RatingDialogState extends State<RatingDialog>
    with SingleTickerProviderStateMixin {
  int _labRating = 0;
  int _nurseRating = 0;
  final TextEditingController _labReasonController = TextEditingController();
  final TextEditingController _nurseReasonController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _labReasonController.dispose();
    _nurseReasonController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  bool get _needsLabReason => _labRating > 0 && _labRating <= 3;
  bool get _needsNurseReason =>
      widget.hasNurse && _nurseRating > 0 && _nurseRating <= 3;

  bool get _canSubmit {
    if (_labRating == 0) return false;
    if (_needsLabReason && _labReasonController.text.trim().isEmpty) {
      return false;
    }
    if (widget.hasNurse && _nurseRating == 0) return false;
    if (_needsNurseReason && _nurseReasonController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _submitRating() async {
    if (!_canSubmit || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final result = await OrderService.rateOrder(
        widget.orderId,
        labRating: _labRating,
        labRatingReason: _needsLabReason ? _labReasonController.text.trim() : null,
        nurseRating: widget.hasNurse ? _nurseRating : null,
        nurseRatingReason: _needsNurseReason ? _nurseReasonController.text.trim() : null,
        feedback: _feedbackController.text.trim().isNotEmpty
            ? _feedbackController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        widget.onRatingSubmitted?.call();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.submitRating),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to submit rating'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStarRating({
    required int rating,
    required ValueChanged<int> onChanged,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1D1D1F),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return GestureDetector(
              onTap: () => onChanged(starValue),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(4),
                child: Icon(
                  starValue <= rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 42,
                  color: starValue <= rating
                      ? const Color(0xFFFFB800)
                      : const Color(0xFFD1D5DB),
                ),
              ),
            );
          }),
        ),
        if (rating > 0 && rating <= 3) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(width: 6),
                Text(
                  _getLowRatingLabel(rating),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getLowRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Very Poor';
      case 2:
        return 'Poor';
      case 3:
        return 'Average';
      default:
        return '';
    }
  }

  Widget _buildReasonField({
    required TextEditingController controller,
    required String hint,
  }) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: controller,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFFEF2F2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFECACA)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFECACA)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.rateYourExperience,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your feedback helps us improve',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Lab Rating
                      _buildStarRating(
                        rating: _labRating,
                        onChanged: (value) => setState(() => _labRating = value),
                        label: '${l10n.labRating} - ${widget.labName}',
                      ),
                      if (_needsLabReason)
                        _buildReasonField(
                          controller: _labReasonController,
                          hint: 'Please tell us why you gave this rating...',
                        ),

                      // Nurse Rating (if nurse was assigned)
                      if (widget.hasNurse) ...[
                        const SizedBox(height: 32),
                        const Divider(height: 1),
                        const SizedBox(height: 24),
                        _buildStarRating(
                          rating: _nurseRating,
                          onChanged: (value) =>
                              setState(() => _nurseRating = value),
                          label:
                              '${l10n.nurseRating}${widget.nurseName != null ? ' - ${widget.nurseName}' : ''}',
                        ),
                        if (_needsNurseReason)
                          _buildReasonField(
                            controller: _nurseReasonController,
                            hint: 'Please tell us why you gave this rating...',
                          ),
                      ],

                      // General Feedback
                      const SizedBox(height: 24),
                      TextField(
                        controller: _feedbackController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: l10n.writeFeedback,
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                          child: Text(
                            l10n.cancel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _canSubmit && !_isLoading
                              ? _submitRating
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            disabledBackgroundColor: const Color(0xFFD1D5DB),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  l10n.submitRating,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
