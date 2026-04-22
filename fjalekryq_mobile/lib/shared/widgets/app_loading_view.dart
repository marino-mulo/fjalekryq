import 'package:flutter/material.dart';
import '../constants/theme.dart';
import 'app_background.dart';

/// Standard indeterminate progress bar used by every loading/splash screen.
///
/// Renders a single 180x6 rounded bar driven by Flutter's indeterminate
/// [LinearProgressIndicator] so the motion is consistent everywhere.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 180,
        height: 6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
          ),
        ),
      ),
    );
  }
}

/// Full-page loading/splash view: the shared [AppBackground] with an
/// [AppLoadingIndicator] centered on it. Use this for every boot/splash
/// screen so they all look identical.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: AppLoadingIndicator(),
      ),
    );
  }
}
