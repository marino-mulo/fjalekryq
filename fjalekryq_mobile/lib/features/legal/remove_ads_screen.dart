import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_top_bar.dart';

class RemoveAdsScreen extends StatefulWidget {
  const RemoveAdsScreen({super.key});

  @override
  State<RemoveAdsScreen> createState() => _RemoveAdsScreenState();
}

class _RemoveAdsScreenState extends State<RemoveAdsScreen> {
  bool _confirming = false;
  bool _purchasing = false;

  Future<void> _purchase() async {
    HapticFeedback.heavyImpact();
    setState(() => _purchasing = true);

    // TODO: wire up real in-app purchase (e.g. in_app_purchase package).
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() => _purchasing = false);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2D5A),
        title: Text(
          'Faleminderit!',
          style: AppFonts.nunito(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        content: Text(
          'Reklamat janë hequr. Ju mund të luani pa ndërprerje.',
          style: AppFonts.quicksand(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context)
              ..pop()
              ..pop(),
            child: Text(
              'Në rregull',
              style: AppFonts.nunito(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const AppTopBar(title: 'HIQNI REKLAMAT'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBanner(),
                      const SizedBox(height: 20),
                      Text(
                        'Çfarë përfitoni',
                        style: AppFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _bullet('Asnjë reklamë banner gjatë lojës'),
                      _bullet('Asnjë reklamë interstitial ndërmjet niveleve'),
                      _bullet('Blerje e vetme — pa abonime'),
                      _bullet('Mbështetni zhvillimin e aplikacionit'),
                      const SizedBox(height: 28),
                      _buildPriceTag(),
                      const SizedBox(height: 20),
                      if (!_confirming)
                        _buildButton(
                          label: 'Vazhdo',
                          color: AppColors.gold,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _confirming = true);
                          },
                        )
                      else
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.gold.withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                'Konfirmoni blerjen prej \$3.99 për të hequr reklamat përgjithmonë.',
                                style: AppFonts.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildButton(
                              label: _purchasing ? 'Duke procesuar…' : 'Po, bli për \$3.99',
                              color: AppColors.gold,
                              onTap: _purchasing ? null : _purchase,
                            ),
                            const SizedBox(height: 10),
                            _buildButton(
                              label: 'Anulo',
                              color: Colors.white.withValues(alpha: 0.12),
                              onTap: _purchasing
                                  ? null
                                  : () => setState(() => _confirming = false),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.block_rounded, color: AppColors.gold, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hiqni të gjitha reklamat me një blerje të vetme prej \$3.99.',
              style: AppFonts.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTag() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            '\$3.99',
            style: AppFonts.nunito(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Blerje e vetme — pa abonime',
            style: AppFonts.quicksand(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppFonts.quicksand(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85),
              ).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: AppFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color == AppColors.gold ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
