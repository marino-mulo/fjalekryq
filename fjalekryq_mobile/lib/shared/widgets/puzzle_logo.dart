import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// The app's brand mark — the Fjalekryq shield logo (mini crossword on a
/// gold-bordered shield with the wordmark banner). Rendered from the
/// shipped PNG asset so it stays pixel-identical to the launcher icon
/// across the publisher splash, onboarding, home header, and loading
/// view.
///
/// Set [animated] = true on splash / loading screens — a soft glow pulse
/// + subtle scale breathe makes the mark feel alive while content loads,
/// without the previous "solve sweep" which clashed with the new logo's
/// fixed letters.
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
    // ~1.8s breathe cycle — slow enough to read as ambient motion, fast
    // enough that a 2–3s loading view still gets a full pulse.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl == null) return _buildLogo(t: 0);

    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (_, __) => _buildLogo(t: _ctrl!.value),
    );
  }

  /// [t] in [0, 1] — drives a gentle glow + scale breathe when animated.
  Widget _buildLogo({required double t}) {
    // Ease the linear controller value into a smoother triangle so the
    // pulse turnaround at 0/1 doesn't feel mechanical.
    final eased = Curves.easeInOut.transform(t);

    // Subtle scale breathe (0.96 → 1.0) — barely visible but adds life.
    final scale = 0.96 + 0.04 * eased;

    // Glow strength matches the breathe so the mark feels like one
    // organism rather than two stacked effects.
    final glowAlpha = 0.18 + 0.32 * eased;
    final glowBlur = widget.size * (0.18 + 0.18 * eased);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: glowAlpha),
                  blurRadius: glowBlur,
                  spreadRadius: widget.size * 0.02,
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/logo.png',
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
