import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/audio_service.dart';
import '../constants/theme.dart';

/// A semi-transparent glassmorphic button with press animation.
class GlassButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onTap;
  final Color? color;
  final bool expanded;
  final double height;

  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    this.iconWidget,
    this.onTap,
    this.color,
    this.expanded = false,
    this.height = 48,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.color ?? AppColors.purpleAccent;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        context.read<AudioService>().play(Sfx.button);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        decoration: BoxDecoration(
          color: _pressed
              ? bgColor.withValues(alpha: 0.3)
              : bgColor.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: bgColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: _pressed ? 0.15 : 0.4),
              blurRadius: _pressed ? 6 : 16,
              offset: Offset(0, _pressed ? 2 : 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.iconWidget != null) ...[
              widget.iconWidget!,
              const SizedBox(width: 8),
            ] else if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Text(widget.label, style: AppTextStyles.button),
          ],
        ),
      ),
    );
  }
}
