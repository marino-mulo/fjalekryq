import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// A semi-transparent glassmorphic button matching the Angular design.
class GlassButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bgColor = color ?? AppColors.buttonPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconWidget != null) ...[
              iconWidget!,
              const SizedBox(width: 8),
            ] else if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: AppTextStyles.button,
            ),
          ],
        ),
      ),
    );
  }
}
