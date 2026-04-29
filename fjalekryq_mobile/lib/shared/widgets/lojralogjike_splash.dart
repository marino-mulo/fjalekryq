import 'package:flutter/material.dart';
import '../constants/theme.dart';
import 'app_background.dart';

/// Publisher splash shown as the very first screen when the app launches.
///
/// This is *only* the LojraLogjike studio mark — no Fjalekryq branding.
/// After it fades out, the app shows [AppLoadingView] (the Fjalekryq
/// loading mark) and finally the home screen.
class LojraLogjikeSplash extends StatefulWidget {
  const LojraLogjikeSplash({super.key});

  @override
  State<LojraLogjikeSplash> createState() => _LojraLogjikeSplashState();
}

class _LojraLogjikeSplashState extends State<LojraLogjikeSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        showCornerPuzzles: false,
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Studio monogram — interlocked "LL" in gold.
                  const _LLMonogram(size: 110),
                  const SizedBox(height: 28),

                  // Wordmark below the monogram.
                  Text(
                    'LojraLogjike',
                    style: AppFonts.nunito(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.gold,
                      letterSpacing: 1.1,
                    ).copyWith(
                      shadows: [
                        Shadow(
                          color: AppColors.gold.withValues(alpha: 0.45),
                          blurRadius: 22,
                        ),
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tagline.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      'Mendo · Luaj · Fito',
                      style: AppFonts.quicksand(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.82),
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Geometric "LL" monogram — two stacked, gold-bordered Ls forming a
/// rounded square. Pure flutter primitives so no asset shipping is
/// required and it scales crisply at any resolution.
class _LLMonogram extends StatelessWidget {
  final double size;
  const _LLMonogram({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1B5C), Color(0xFF15093A)],
        ),
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.55),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.30),
            blurRadius: size * 0.4,
            spreadRadius: size * 0.02,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _LLPainter(),
      ),
    );
  }
}

class _LLPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.13;
    final paint = Paint()
      ..color = AppColors.gold
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // First L (top-left, larger).
    final l1Top = Offset(size.width * 0.27, size.height * 0.22);
    final l1Bend = Offset(size.width * 0.27, size.height * 0.62);
    final l1End = Offset(size.width * 0.55, size.height * 0.62);
    canvas.drawPath(
      Path()
        ..moveTo(l1Top.dx, l1Top.dy)
        ..lineTo(l1Bend.dx, l1Bend.dy)
        ..lineTo(l1End.dx, l1End.dy),
      paint,
    );

    // Second L (offset down-right, interlocking).
    final l2Top = Offset(size.width * 0.50, size.height * 0.38);
    final l2Bend = Offset(size.width * 0.50, size.height * 0.78);
    final l2End = Offset(size.width * 0.78, size.height * 0.78);
    canvas.drawPath(
      Path()
        ..moveTo(l2Top.dx, l2Top.dy)
        ..lineTo(l2Bend.dx, l2Bend.dy)
        ..lineTo(l2End.dx, l2End.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
