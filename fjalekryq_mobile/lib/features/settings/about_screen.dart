import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/constants/theme.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_top_bar.dart';

/// "About Game" page — shows the app name, version, and a support
/// address. Apple and Google both expect a clearly discoverable
/// support contact for a published app; this page satisfies that.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Keep in sync with the version field in pubspec.yaml. Hard-coded
  // intentionally so this screen has zero runtime dependencies — the
  // package_info_plus plugin can replace this later if we need
  // auto-sync.
  static const String _appVersion = '1.0.0';
  static const String _supportEmail = 'support@fjalekryq.com';

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
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.45),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.extension_rounded,
                          color: AppColors.gold,
                          size: 44,
                        ),
                      ),
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
                      _infoRow(
                        label: 'Mbështetje',
                        value: _supportEmail,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Clipboard.setData(
                              const ClipboardData(text: _supportEmail));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Adresa u kopjua',
                                style: AppFonts.quicksand(fontSize: 13),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _infoRow(
                        label: 'Zhvilluar nga',
                        value: 'Fjalëkryq Team',
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '© ${DateTime.now().year} Fjalëkryq',
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

  Widget _infoRow({
    required String label,
    required String value,
    VoidCallback? onTap,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppFonts.quicksand(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.45),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.copy_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
