import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_theme.dart';

/// Floating CTA button with state animations
class FloatingCTAButton extends StatefulWidget {
  final bool isAdded;
  final bool isLoading;
  final VoidCallback onTap;
  final String addText;
  final String addedText;

  const FloatingCTAButton({
    super.key,
    required this.isAdded,
    required this.isLoading,
    required this.onTap,
    required this.addText,
    required this.addedText,
  });

  @override
  State<FloatingCTAButton> createState() => _FloatingCTAButtonState();
}

class _FloatingCTAButtonState extends State<FloatingCTAButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(FloatingCTAButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAdded != oldWidget.isAdded) {
      _controller.forward().then((_) {
        _controller.reverse();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isLoading) return;
    HapticFeedback.mediumImpact();
    _controller.forward().then((_) {
      _controller.reverse();
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: widget.isAdded || widget.isLoading
                ? Colors.black.withValues(alpha: 0.1)
                : AppTheme.primaryColor.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: AnimatedScale(
        scale: _scaleAnimation.value,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: _handleTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: (widget.isAdded && !widget.isLoading)
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor,
                        Color(0xFF6366F1),
                      ],
                    ),
              color: (widget.isAdded && !widget.isLoading)
                  ? AppTheme.gray200
                  : null,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Row(
                        key: ValueKey(widget.isAdded),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isAdded
                                ? Icons.check_circle_rounded
                                : Icons.add_circle_rounded,
                            size: 26,
                            color: widget.isAdded
                                ? AppTheme.gray600
                                : AppTheme.white,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.isAdded ? widget.addedText : widget.addText,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: widget.isAdded
                                  ? AppTheme.gray600
                                  : AppTheme.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
