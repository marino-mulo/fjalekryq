import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// App logo — a single stylised jigsaw puzzle piece rendered from SVG.
///
/// Pass [animated] = true on loading screens to get a diagonal shimmer
/// sweep passing across the piece every ~2.2 seconds. The motion is
/// intentionally subtle (no scale, no rotation) — just a bright band
/// travelling from top-left to bottom-right, the way polished splash
/// screens hint at "working in the background".
class AppLogo extends StatefulWidget {
  final double size;
  final bool animated;

  const AppLogo({
    super.key,
    this.size = 180,
    this.animated = false,
  });

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AppLogo old) {
    super.didUpdateWidget(old);
    if (widget.animated && _ctrl == null) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..repeat();
    } else if (!widget.animated && _ctrl != null) {
      _ctrl!.dispose();
      _ctrl = null;
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svg = SvgPicture.asset(
      'assets/images/logo.svg',
      width: widget.size,
      height: widget.size,
    );

    if (!widget.animated || _ctrl == null) return svg;

    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (_, child) {
        // Progress goes from -0.4 → 1.4 so the band starts fully off the
        // top-left edge and exits fully past the bottom-right, then
        // immediately restarts (no visible rubber-band).
        final t = -0.4 + _ctrl!.value * 1.8;

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Colors.transparent,
                Colors.transparent,
                Color(0x99FFFFFF), // bright band
                Colors.transparent,
                Colors.transparent,
              ],
              stops: [
                (t - 0.30).clamp(0.0, 1.0),
                (t - 0.12).clamp(0.0, 1.0),
                t.clamp(0.0, 1.0),
                (t + 0.12).clamp(0.0, 1.0),
                (t + 0.30).clamp(0.0, 1.0),
              ],
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: svg,
    );
  }
}
