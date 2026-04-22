import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// The app's brand mark: a purple rounded tile with a puzzle-grid icon.
///
/// Lifted from the original login/onboarding header so the same mark is
/// used everywhere (onboarding, home header, brand splash, loading view).
///
/// Set [animated] = true to get a breathing pulse (scale + glow) — used
/// as the "loading indicator" on splash / loading screens.
class PuzzleLogo extends StatefulWidget {
  final double size;
  final bool animated;

  const PuzzleLogo({
    super.key,
    this.size = 88,
    this.animated = false,
  });

  @override
  State<PuzzleLogo> createState() => _PuzzleLogoState();
}

class _PuzzleLogoState extends State<PuzzleLogo>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.animated) _startAnim();
  }

  @override
  void didUpdateWidget(covariant PuzzleLogo old) {
    super.didUpdateWidget(old);
    if (widget.animated && _ctrl == null) {
      _startAnim();
    } else if (!widget.animated && _ctrl != null) {
      _ctrl!.dispose();
      _ctrl = null;
    }
  }

  void _startAnim() {
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl == null) return _buildTile(glow: 0.3, scale: 1.0);

    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (_, __) {
        // Sinusoidal ease so the motion looks like breathing, not linear.
        final t = (math.sin(_ctrl!.value * math.pi) + 1) / 2;
        return _buildTile(
          glow: 0.22 + 0.38 * t,
          scale: 0.94 + 0.10 * t,
        );
      },
    );
  }

  Widget _buildTile({required double glow, required double scale}) {
    // Tile styling scales with the requested logo size so the visual
    // weight stays consistent between 44px badges and 180px splash marks.
    final radius = widget.size * 0.25;
    final border = (widget.size * 0.023).clamp(1.5, 3.0);
    final iconSize = widget.size * 0.5;
    final blur = widget.size * 0.36;
    final spread = widget.size * 0.023;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: AppColors.purpleAccent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: AppColors.purpleAccent.withValues(alpha: 0.45),
            width: border,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.purpleAccent.withValues(alpha: glow),
              blurRadius: blur,
              spreadRadius: spread,
            ),
          ],
        ),
        child: Icon(
          Icons.grid_view_rounded,
          color: const Color(0xFFD8B4FE),
          size: iconSize,
        ),
      ),
    );
  }
}
