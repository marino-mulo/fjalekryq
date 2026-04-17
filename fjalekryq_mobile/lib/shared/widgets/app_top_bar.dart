import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';

/// Unified top bar used across every full-page screen.
///
/// Layout:
///   ┌────────────────────────────────────────────────────────┐
///   │  [◀]            TITLE (centered)            [trailing] │
///   └────────────────────────────────────────────────────────┘
///
/// - Back button: 40×40 glass tile with rounded back arrow.
/// - Title: centered, nunito w900 with wide letter-spacing.
/// - Trailing: optional widget (e.g. coin balance).
class AppTopBar extends StatelessWidget {
  final String title;

  /// Optional leading icon shown next to the title (e.g. trophy on the
  /// leaderboard screen).
  final IconData? titleIcon;

  /// Optional override for the title text style.
  final TextStyle? titleStyle;

  /// Optional widget shown on the right (defaults to a spacer that balances
  /// the back button so the title stays truly centered).
  final Widget? trailing;

  /// Optional callback; defaults to `Navigator.pop`.
  final VoidCallback? onBack;

  /// Whether to show the back button at all.
  final bool showBack;

  const AppTopBar({
    super.key,
    required this.title,
    this.titleIcon,
    this.titleStyle,
    this.trailing,
    this.onBack,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTitleStyle = titleStyle ??
        AppFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.5,
          color: Colors.white.withValues(alpha: 0.9),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1F4A).withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          if (showBack)
            _GlassBackButton(
              onTap: onBack ??
                  () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                  },
            )
          else
            const SizedBox(width: 40),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (titleIcon != null) ...[
                    Icon(titleIcon, color: AppColors.gold, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolvedTitleStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          trailing ?? const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _GlassBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GlassBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
