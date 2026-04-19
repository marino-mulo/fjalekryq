import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/connectivity_service.dart';
import '../constants/theme.dart';

/// Full-area "no internet" placeholder. Drop this into a screen body /
/// tab when a network-only feature is blocked by offline state.
///
/// The message is caller-supplied so we can say "Kërkohet internet për
/// renditjen" on the leaderboard, "Kërkohet internet për reklamën" on
/// ads, etc. — every surface speaks the same visual language but tells
/// the user exactly what's blocked.
class OfflineView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const OfflineView({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "S'ka internet",
              textAlign: TextAlign.center,
              style: AppFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.purpleAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.purpleAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded,
                          color: Color(0xFFE2C9FF), size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'Provo përsëri',
                        style: AppFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE2C9FF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reactive strip that appears only when `ConnectivityService.isOffline`
/// is true. Drop it in at the top of a screen (or above a section) so
/// the user sees the offline state without the content being hidden.
///
/// Rebuilds automatically when connectivity flips — no app restart
/// required.
class OfflineBanner extends StatelessWidget {
  final EdgeInsetsGeometry margin;
  final String? message;

  const OfflineBanner({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(16, 12, 16, 4),
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityService>().isOnline;
    if (online) return const SizedBox.shrink();

    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E5C).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message ?? 'Nuk jeni të lidhur me internet.',
              style: AppFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a short snackbar for transient "no internet" feedback — used
/// when the user taps a network-only action (watch ad) but we don't
/// want to block the whole screen.
void showOfflineSnack(BuildContext context, {String? message}) {
  final msg = message ?? 'Nuk jeni të lidhur me internet.';
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: AppFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A2E5C),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
}
