import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animation style for [AnimatedIconFx].
enum IconFxStyle {
  /// Continuous gentle scale + opacity breathing. Good for "available" cues
  /// (hint lightbulb, ad-watch video badges).
  pulse,

  /// One-shot scale-in bounce when the widget appears. Good for success
  /// confirmations (check_circle, gift box on sheet entry).
  bounceIn,

  /// One-shot scale + light rotation pop, then settles. Good for hero
  /// reward icons (claim coin).
  spinPop,

  /// Continuous flame-like flicker (scale wobble + slight rotation +
  /// opacity). Good for streak fire.
  flicker,

  /// One-shot quick horizontal shake. Good for warning / fail icons.
  shake,

  /// Continuous gold sweep / glow pulse. Good for crown / premium badges.
  shimmer,
}

/// Drop-in replacement for [Icon] that adds a subtle animation based on
/// [style]. Built on Flutter primitives — no external assets required.
class AnimatedIconFx extends StatefulWidget {
  const AnimatedIconFx(
    this.icon, {
    super.key,
    this.style = IconFxStyle.pulse,
    this.color,
    this.size,
    this.shimmerColor,
  });

  final IconData icon;
  final IconFxStyle style;
  final Color? color;
  final double? size;

  /// Highlight color for [IconFxStyle.shimmer]. Defaults to white.
  final Color? shimmerColor;

  @override
  State<AnimatedIconFx> createState() => _AnimatedIconFxState();
}

class _AnimatedIconFxState extends State<AnimatedIconFx>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _durationFor(widget.style));
    _start();
  }

  @override
  void didUpdateWidget(covariant AnimatedIconFx old) {
    super.didUpdateWidget(old);
    if (old.style != widget.style) {
      _c.stop();
      _c.duration = _durationFor(widget.style);
      _c.reset();
      _start();
    }
  }

  void _start() {
    switch (widget.style) {
      case IconFxStyle.pulse:
      case IconFxStyle.flicker:
      case IconFxStyle.shimmer:
        _c.repeat();
        break;
      case IconFxStyle.bounceIn:
      case IconFxStyle.spinPop:
      case IconFxStyle.shake:
        _c.forward(from: 0);
        break;
    }
  }

  Duration _durationFor(IconFxStyle s) {
    switch (s) {
      case IconFxStyle.pulse:
        return const Duration(milliseconds: 1400);
      case IconFxStyle.bounceIn:
        return const Duration(milliseconds: 520);
      case IconFxStyle.spinPop:
        return const Duration(milliseconds: 700);
      case IconFxStyle.flicker:
        return const Duration(milliseconds: 900);
      case IconFxStyle.shake:
        return const Duration(milliseconds: 460);
      case IconFxStyle.shimmer:
        return const Duration(milliseconds: 1800);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Icon(widget.icon, color: widget.color, size: widget.size);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => _apply(base, _c.value),
    );
  }

  Widget _apply(Widget child, double t) {
    switch (widget.style) {
      case IconFxStyle.pulse:
        // Smooth sine breathing 0..1..0
        final s = 1.0 + 0.10 * math.sin(t * 2 * math.pi);
        final o = 0.78 + 0.22 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
        return Opacity(opacity: o, child: Transform.scale(scale: s, child: child));

      case IconFxStyle.bounceIn:
        // Elastic-ish out: overshoot then settle.
        final eased = Curves.elasticOut.transform(t.clamp(0.0, 1.0));
        final s = 0.4 + 0.6 * eased;
        return Transform.scale(scale: s, child: child);

      case IconFxStyle.spinPop:
        // 0..0.45 grow & rotate, 0.45..1 settle to 1.0 / 0 deg.
        final grow = Curves.easeOutBack.transform((t / 0.45).clamp(0.0, 1.0));
        final settle = Curves.easeOut.transform(((t - 0.45) / 0.55).clamp(0.0, 1.0));
        final s = 0.6 + 0.55 * grow - 0.15 * settle;
        final rot = (1 - settle) * 0.35 * grow;
        return Transform.rotate(
          angle: rot,
          child: Transform.scale(scale: s, child: child),
        );

      case IconFxStyle.flicker:
        // Two overlapping sines for an organic flame look.
        final a = math.sin(t * 2 * math.pi);
        final b = math.sin(t * 2 * math.pi * 1.7 + 1.3);
        final s = 1.0 + 0.07 * a + 0.04 * b;
        final rot = 0.05 * b;
        final o = 0.82 + 0.18 * (0.5 + 0.5 * a);
        return Opacity(
          opacity: o,
          child: Transform.rotate(
            angle: rot,
            child: Transform.scale(scale: s, child: child),
          ),
        );

      case IconFxStyle.shake:
        // Damped sine: big at start, small at end.
        final damp = 1.0 - t;
        final dx = math.sin(t * 2 * math.pi * 3) * 4.0 * damp;
        return Transform.translate(offset: Offset(dx, 0), child: child);

      case IconFxStyle.shimmer:
        // Gentle glow pulse: scale + an overlaid highlight that sweeps across.
        final glow = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
        final s = 1.0 + 0.04 * glow;
        final highlight = (widget.shimmerColor ?? Colors.white)
            .withValues(alpha: 0.55 * glow);
        return Transform.scale(
          scale: s,
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) {
              final pos = -1.0 + 2.0 * t; // -1..1 sweep
              return LinearGradient(
                begin: Alignment(pos - 0.6, -1),
                end: Alignment(pos + 0.6, 1),
                colors: [
                  Colors.transparent,
                  highlight,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(rect);
            },
            child: child,
          ),
        );
    }
  }
}
