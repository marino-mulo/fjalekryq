import 'package:flutter/material.dart';
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
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1D3A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
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
        const SizedBox(height: 16),
        Text('Shkëmbe Shkronjat', style: AppFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        // Demo: two tiles with arrows
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _demoTile('F', AppColors.cellGrey),
            const SizedBox(width: 12),
            Icon(Icons.swap_vert, color: Colors.white.withValues(alpha: 0.5), size: 28),
            const SizedBox(width: 12),
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
        const SizedBox(height: 16),
        Text('Kuptimi i Ngjyrave', style: AppFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        _colorRow('M', AppColors.cellGreen, 'Shkronja është në vendin e saktë'),
        const SizedBox(height: 10),
        _colorRow('A', AppColors.cellYellow, 'Shkronja i përket fjalës por është në vendin e gabuar'),
        const SizedBox(height: 10),
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
        const SizedBox(height: 16),
        Text('Butoni "Ndihmë" ⭐', style: AppFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        // Hint button demo (yellow with shadow like web)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cellYellow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA8943A),
                offset: const Offset(3, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.white, size: 28),
              const SizedBox(height: 6),
              Text('Ndihmë', style: AppFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
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
        const SizedBox(height: 16),
        Text('Yjet & Lëvizjet', style: AppFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        // Stars table
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              _starRow('⭐⭐⭐', '7 lëvizje të mbetura'),
              const SizedBox(height: 6),
              _starRow('⭐⭐', '3 – 6 lëvizje të mbetura'),
              const SizedBox(height: 6),
              _starRow('⭐', '1 – 2 lëvizje të mbetura'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ruleRow(Icons.check, const Color(0xFF4ADE80), 'Çdo shkëmbim heq 1 lëvizje.'),
        const SizedBox(height: 8),
        _ruleRow(Icons.check, const Color(0xFFFCD34D), 'Ndihmë nuk heq lëvizje.'),
        const SizedBox(height: 8),
        _ruleRow(Icons.close, const Color(0xFFFCA5A5), 'Nëse mbarojnë lëvizjet — humb lojën.'),
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
        const SizedBox(height: 16),
        Text('Butoni "Zgjidh"', style: AppFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        // Solve button demo (green with shadow like web)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cellGreen,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4D8A48),
                offset: const Offset(3, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
              const SizedBox(height: 6),
              Text('Zgjidh', style: AppFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.purpleAccent,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        text,
        style: AppFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _demoTile(String letter, Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: AppFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _desc(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        color: Colors.white.withValues(alpha: 0.7),
        height: 1.5,
      ),
    );
  }

  Widget _nextButton(String label) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onNext,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.purpleAccent.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.purpleAccent.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.purpleAccent.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppFonts.nunito(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
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
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _starRow(String stars, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(stars, style: const TextStyle(fontSize: 14, letterSpacing: 1)),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.65),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _ruleRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
