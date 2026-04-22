import 'package:flutter/material.dart';
import 'app_background.dart';
import 'puzzle_logo.dart';

/// Standard loading mark used by every loading/splash screen — the
/// animated brand [PuzzleLogo] centered on the host surface.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: PuzzleLogo(size: 88, animated: true),
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
