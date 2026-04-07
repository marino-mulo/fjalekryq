import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Small coin icon + amount badge used across multiple screens.
class CoinBadge extends StatelessWidget {
  final int amount;
  final double iconSize;
  final double fontSize;
  final VoidCallback? onTap;

  const CoinBadge({
    super.key,
    required this.amount,
    this.iconSize = 16,
    this.fontSize = 13,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.coinBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CoinIcon(size: iconSize),
            const SizedBox(width: 4),
            Text(
              '$amount',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small gold coin SVG-like icon rendered as a custom painter.
class _CoinIcon extends StatelessWidget {
  final double size;
  const _CoinIcon({this.size = 16});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CoinPainter()),
    );
  }
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Gold circle
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppColors.gold,
    );

    // Dollar sign text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '\$',
        style: TextStyle(
          color: AppColors.goldDark,
          fontSize: size.width * 0.55,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
