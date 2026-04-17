import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/audio_service.dart';
import '../constants/theme.dart';

/// Canonical tap-target button for the whole app.
///
/// Visual variants share the same layout (icon + label, press-down animation,
/// optional loading spinner) and only differ in tint:
/// * [AppButtonVariant.primary]   — purple glass (main CTA)
/// * [AppButtonVariant.secondary] — white-frosted glass (neutral / cancel)
/// * [AppButtonVariant.gold]      — gold accent (coin / reward actions)
/// * [AppButtonVariant.danger]    — red accent (destructive actions)
enum AppButtonVariant { primary, secondary, gold, danger }

class AppButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onTap;
  final AppButtonVariant variant;

  /// When true, stretches to fill the available horizontal space.
  final bool expanded;

  /// When true, shows a centered spinner instead of the label.
  final bool loading;

  /// Fixed height (defaults to 48).
  final double height;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.iconWidget,
    this.onTap,
    this.variant = AppButtonVariant.primary,
    this.expanded = false,
    this.loading = false,
    this.height = 48,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  _Palette get _palette {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return _Palette(AppColors.purpleAccent, Colors.white);
      case AppButtonVariant.secondary:
        return _Palette(Colors.white, Colors.white);
      case AppButtonVariant.gold:
        return _Palette(AppColors.gold, Colors.white);
      case AppButtonVariant.danger:
        return _Palette(AppColors.redAccent, Colors.white);
    }
  }

  bool get _disabled => widget.onTap == null || widget.loading;

  void _handleTapUp() {
    setState(() => _pressed = false);
    if (_disabled) return;
    HapticFeedback.lightImpact();
    context.read<AudioService>().play(Sfx.button);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final secondary = widget.variant == AppButtonVariant.secondary;

    final fillAlpha = _pressed ? 0.30 : (secondary ? 0.10 : 0.22);
    final borderAlpha = secondary ? 0.22 : 0.50;
    final shadowAlpha = _pressed ? 0.15 : (secondary ? 0.25 : 0.40);

    return GestureDetector(
      onTapDown: _disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: _disabled ? null : (_) => _handleTapUp(),
      onTapCancel: _disabled ? null : () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        decoration: BoxDecoration(
          color: palette.tint.withValues(alpha: fillAlpha),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: palette.tint.withValues(alpha: borderAlpha),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (secondary ? Colors.black : palette.tint)
                  .withValues(alpha: shadowAlpha),
              blurRadius: _pressed ? 8 : 16,
              offset: Offset(0, _pressed ? 2 : 4),
            ),
          ],
        ),
        child: widget.loading
            ? Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.fg,
                  ),
                ),
              )
            : Row(
                mainAxisSize: widget.expanded
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.iconWidget != null) ...[
                    widget.iconWidget!,
                    const SizedBox(width: 8),
                  ] else if (widget.icon != null) ...[
                    Icon(widget.icon, color: palette.fg, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      style: AppTextStyles.button.copyWith(color: palette.fg),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Palette {
  final Color tint;
  final Color fg;
  const _Palette(this.tint, this.fg);
}
