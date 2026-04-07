import 'package:flutter/material.dart';
import '../../core/services/coin_service.dart';
import '../../shared/constants/theme.dart';

/// Tutorial phase enum matching the Angular implementation.
/// 0=off, 1=swap modal, 2=interactive swap, 3=colors modal, 4=hint modal,
/// 5=interactive hint, 6=moves modal, 7=solve modal, 8=interactive solve, 9=done banner
typedef TutorialPhase = int;

/// Builds a tutorial overlay widget for the given phase.
/// Returns null if the phase doesn't need a blocking overlay.
class TutorialOverlay extends StatelessWidget {
  final TutorialPhase phase;
  final VoidCallback onNext;

  const TutorialOverlay({
    super.key,
    required this.phase,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (phase) {
      case 1:
        return _buildSwapModal();
      case 3:
        return _buildColorsModal();
      case 4:
        return _buildHintModal();
      case 6:
        return _buildMovesModal();
      case 7:
        return _buildSolveModal();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSwapModal() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBadge('HAPI 1 nga 5'),
        const SizedBox(height: 12),
        const Text('Shkëmbe Shkronjat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 16),
        // Demo: two tiles with arrows
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _demoTile('F', AppColors.cellGrey),
            const SizedBox(width: 8),
            Icon(Icons.swap_vert, color: Colors.white.withValues(alpha: 0.5), size: 28),
            const SizedBox(width: 8),
            _demoTile('A', AppColors.cellGrey),
          ],
        ),
        const SizedBox(height: 16),
        _desc('Ke 8 lëvizje të mbetura dhe po fiton 3 yje! Çdo shkëmbim heq 1 lëvizje.'),
        const SizedBox(height: 16),
        _nextButton('Gati, po provoj!'),
      ],
    );
  }

  Widget _buildColorsModal() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBadge('HAPI 2 nga 5'),
        const SizedBox(height: 12),
        const Text('Kuptimi i Ngjyrave', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 16),
        _colorRow('M', AppColors.cellGreen, 'Shkronja është në vendin e saktë'),
        const SizedBox(height: 8),
        _colorRow('A', AppColors.cellYellow, 'Shkronja i përket fjalës por është në vendin e gabuar'),
        const SizedBox(height: 8),
        _colorRow('B', AppColors.cellGrey, 'Shkronja nuk i përket asnjë fjale'),
        const SizedBox(height: 16),
        _nextButton('Kuptova!'),
      ],
    );
  }

  Widget _buildHintModal() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBadge('HAPI 3 nga 5'),
        const SizedBox(height: 12),
        const Text('Butoni "Ndihmë"', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lightbulb, color: AppColors.gold, size: 28),
              SizedBox(width: 8),
              Text('Ndihmë', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _desc('Ndihmë vendos 1 shkronjë në vendin e duhur pa shpenzuar lëvizje! 7 lëvizje = 3 yje. Përdor Ndihmën dhe ruaji!'),
        const SizedBox(height: 16),
        _nextButton('Kuptova, provoje!'),
      ],
    );
  }

  Widget _buildMovesModal() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBadge('HAPI 4 nga 5'),
        const SizedBox(height: 12),
        const Text('Yjet & Lëvizjet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 16),
        _starRow('⭐⭐⭐', '7 lëvizje të mbetura'),
        const SizedBox(height: 6),
        _starRow('⭐⭐', '3 – 6 lëvizje të mbetura'),
        const SizedBox(height: 6),
        _starRow('⭐', '1 – 2 lëvizje të mbetura'),
        const SizedBox(height: 16),
        _ruleRow(Icons.check, AppColors.greenAccent, 'Çdo shkëmbim heq 1 lëvizje.'),
        const SizedBox(height: 4),
        _ruleRow(Icons.check, AppColors.yellowAccent, 'Ndihmë nuk heq lëvizje.'),
        const SizedBox(height: 4),
        _ruleRow(Icons.close, AppColors.redAccent, 'Nëse mbarojnë lëvizjet — humb lojën.'),
        const SizedBox(height: 16),
        _nextButton('Kuptova!'),
      ],
    );
  }

  Widget _buildSolveModal() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBadge('HAPI 5 nga 5'),
        const SizedBox(height: 12),
        const Text('Butoni "Zgjidh"', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cellGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: AppColors.cellGreen, size: 28),
              SizedBox(width: 8),
              Text('Zgjidh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _desc('Përdor Zgjidh kur do të zgjidhësh një fjalë të plotë pa hequr lëvizje!'),
        const SizedBox(height: 16),
        _nextButton('Provoje tani!'),
      ],
    );
  }

  // ── Helpers ──

  Widget _stepBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cellGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.cellGreen,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _demoTile(String letter, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }

  Widget _desc(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7), height: 1.4),
    );
  }

  Widget _nextButton(String label) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onNext,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cellGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }

  Widget _colorRow(String letter, Color color, String text) {
    return Row(
      children: [
        _demoTile(letter, color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ),
      ],
    );
  }

  Widget _starRow(String stars, String text) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(stars, style: const TextStyle(fontSize: 14)),
        ),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _ruleRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
        ),
      ],
    );
  }
}

/// Non-blocking banner for interactive tutorial phases (2, 5, 8).
class TutorialBanner extends StatelessWidget {
  final String text;

  const TutorialBanner({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
