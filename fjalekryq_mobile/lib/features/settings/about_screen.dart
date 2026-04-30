import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/constants/theme.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/puzzle_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _appVersion = '1.0.0';

  static const String _playStoreUrl =
      'https://play.google.com/store/apps/developer?id=LojraLogjike';
  static const String _appStoreUrl =
      'https://apps.apple.com/developer/lojralogjike';
  static const String _websiteUrl = 'https://lojralogjike.al';

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMoreGames(BuildContext context) async {
    HapticFeedback.selectionClick();
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    await _openUrl(isAndroid ? _playStoreUrl : _appStoreUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const AppTopBar(title: 'RRETH LOJËS'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      const PuzzleLogo(size: 88),
                      const SizedBox(height: 18),
                      Text(
                        'Fjalëkryq',
                        style: AppFonts.nunito(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Versioni $_appVersion',
                        style: AppFonts.quicksand(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _linkRow(
                        icon: Icons.apps_rounded,
                        label: 'Lojëra të tjera nga LojraLogjike',
                        onTap: () => _openMoreGames(context),
                      ),
                      const SizedBox(height: 10),
                      _linkRow(
                        icon: Icons.language_rounded,
                        label: 'Vizitoni lojralogjike.al',
                        onTap: () => _openUrl(_websiteUrl),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        '© 2026 LojraLogjike',
                        style: AppFonts.quicksand(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
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

  Widget _linkRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
