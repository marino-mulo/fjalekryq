import 'package:flutter/material.dart';
import '../constants/theme.dart';
import 'app_background.dart';
import 'app_logo.dart';

/// Brand splash shown as the very first screen when the app launches.
///
/// Renders the "LojraLogjike" mark (animated puzzle piece + wordmark +
/// tagline) on top of the shared [AppBackground]. It is shown for a
/// fixed duration, after which the app swaps to the loading view and
/// then the home screen.
class LojraLogjikeSplash extends StatelessWidget {
  const LojraLogjikeSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo with shimmer sweep.
              const AppLogo(size: 150, animated: true),
              const SizedBox(height: 26),

              // Wordmark — gold, tracked out, heavy weight.
              Text(
                'LojraLogjike',
                style: AppFonts.nunito(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gold,
                  letterSpacing: 1.2,
                ).copyWith(
                  shadows: [
                    Shadow(
                      color: AppColors.gold.withValues(alpha: 0.45),
                      blurRadius: 24,
                    ),
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Tagline pill.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
    );
  }
}
