import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A large status button that requires a long press to confirm selection.
///
/// While the user holds down, a circular progress animation fills. Once
/// complete (after [confirmDuration]), [onConfirmed] fires with haptic
/// feedback. Tapping a selected button calls [onDeselected].
class StatusActionButton extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onConfirmed;
  final VoidCallback? onDeselected;
  final Duration confirmDuration;

  const StatusActionButton({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    this.isDisabled = false,
    required this.onConfirmed,
    this.onDeselected,
    this.confirmDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<StatusActionButton> createState() => _StatusActionButtonState();
}

class _StatusActionButtonState extends State<StatusActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.confirmDuration,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onConfirmed();
        _controller.reset();
        if (mounted) setState(() => _isPressed = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails _) {
    if (widget.isSelected || widget.isDisabled) return;
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    _cancelAnimation();
  }

  void _onLongPressCancel() {
    _cancelAnimation();
  }

  void _cancelAnimation() {
    if (_controller.isAnimating) {
      _controller.reset();
      if (mounted) setState(() => _isPressed = false);
    }
  }

  void _onTap() {
    if (widget.isDisabled) return;
    if (widget.isSelected) {
      HapticFeedback.lightImpact();
      widget.onDeselected?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isSelected
        ? widget.color.withValues(alpha: 0.25)
        : _isPressed
            ? widget.color.withValues(alpha: 0.12)
            : Colors.transparent;

    final borderColor = widget.isSelected
        ? widget.color
        : widget.isDisabled
            ? Colors.grey.shade800
            : widget.color.withValues(alpha: 0.5);

    final textColor = widget.isDisabled
        ? Colors.grey.shade600
        : widget.isSelected
            ? widget.color
            : Colors.white70;

    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress ring around icon
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isPressed && !widget.isSelected)
                        CircularProgressIndicator(
                          value: _controller.value,
                          strokeWidth: 3,
                          backgroundColor:
                              widget.color.withValues(alpha: 0.2),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(widget.color),
                        ),
                      Icon(
                        widget.isSelected ? Icons.check_circle : widget.icon,
                        size: 32,
                        color: textColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.isSelected ? 'Seçildi' : 'Basılı tut',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
