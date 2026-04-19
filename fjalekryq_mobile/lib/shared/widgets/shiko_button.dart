import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/connectivity_service.dart';
import '../constants/theme.dart';

/// Unified "Shiko" (watch ad) button used across the entire app.
///
/// Three variants controlled by [size]:
/// - [ShikoSize.small]  — tiny pill badge (e.g. on control buttons)
/// - [ShikoSize.medium] — inline pill (e.g. in banners, win/loss screens)
/// - [ShikoSize.large]  — full-width row with icon + text (e.g. in shop, daily reward)
///
/// Listens to [ConnectivityService]: when the device goes offline, the
/// button is disabled, its icon flips to `wifi_off`, and the label is
/// replaced with "Nuk jeni të lidhur me internet." — in real time, no
/// app restart required.
enum ShikoSize { small, medium, large }

class ShikoButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  final ShikoSize size;
  /// Optional trailing label like "×2" shown as a badge.
  final String? badge;
  /// Optional custom label. Defaults to 'Shiko' for small/medium, 'Shiko reklamë' for large.
  final String? label;

  const ShikoButton({
    super.key,
    this.onTap,
    this.loading = false,
    this.size = ShikoSize.medium,
    this.badge,
    this.label,
  });

  static const _offlineLabel      = 'Nuk jeni të lidhur me internet';
  static const _offlineLabelShort = "S'ka internet";
  static const _offlineColor      = Color(0xFFB8C5DC);

  @override
  Widget build(BuildContext context) {
    final offline =
        context.select<ConnectivityService, bool>((c) => c.isOffline);

    switch (size) {
      case ShikoSize.small:
        return _buildSmall(offline: offline);
      case ShikoSize.medium:
        return _buildMedium(offline: offline);
      case ShikoSize.large:
        return _buildLarge(offline: offline);
    }
  }

  Color _borderColor(bool offline, {double alpha = 0.5}) => offline
      ? _offlineColor.withValues(alpha: alpha * 0.6)
      : AppColors.purpleAccent.withValues(alpha: alpha);

  Color _bgColor(bool offline, double alpha) => offline
      ? _offlineColor.withValues(alpha: alpha * 0.6)
      : AppColors.purpleAccent.withValues(alpha: alpha);

  Color _contentColor(bool offline) => offline
      ? _offlineColor
      : const Color(0xFFE2C9FF);

  /// Tiny pill badge — e.g. "▶ Shiko" on control buttons
  Widget _buildSmall({required bool offline}) {
    return GestureDetector(
      onTap: (loading || offline) ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: _bgColor(offline, 0.2),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: _borderColor(offline, alpha: 0.4), width: 1.5),
          boxShadow: offline
              ? const []
              : [
                  BoxShadow(color: AppColors.purpleAccent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                ],
        ),
        child: loading
            ? SizedBox(
                width: 10, height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: _contentColor(offline)),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    offline ? Icons.wifi_off_rounded : Icons.play_arrow,
                    color: _contentColor(offline),
                    size: 10,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    offline ? _offlineLabelShort : (label ?? 'Shiko'),
                    style: AppFonts.nunito(
                      color: _contentColor(offline),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Medium inline pill — e.g. in banners, win/loss card buttons
  Widget _buildMedium({required bool offline}) {
    return GestureDetector(
      onTap: (loading || offline) ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _bgColor(offline, 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _borderColor(offline, alpha: 0.5), width: 1.5),
              boxShadow: offline
                  ? const []
                  : [
                      BoxShadow(color: AppColors.purpleAccent.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 4)),
                    ],
            ),
            child: loading
                ? SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: _contentColor(offline)),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        offline ? Icons.wifi_off_rounded : Icons.play_arrow,
                        color: _contentColor(offline),
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        offline ? _offlineLabelShort : (label ?? 'Shiko'),
                        style: AppFonts.nunito(
                          color: _contentColor(offline),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
          if (badge != null && !offline)
            Positioned(
              top: -7,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4B400),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Text(
                  badge!,
                  style: AppFonts.nunito(
                    color: const Color(0xFF7A3F00),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Large row — e.g. in shop and daily reward sheets
  Widget _buildLarge({required bool offline}) {
    return GestureDetector(
      onTap: (loading || offline) ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _bgColor(offline, 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor(offline, alpha: 0.35)),
          boxShadow: offline
              ? const []
              : [
                  BoxShadow(color: AppColors.purpleAccent.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _contentColor(offline)),
              )
            else
              Icon(
                offline ? Icons.wifi_off_rounded : Icons.play_arrow,
                color: _contentColor(offline),
                size: 18,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                offline ? _offlineLabel : (label ?? 'Shiko reklamë'),
                style: AppFonts.nunito(
                  color: _contentColor(offline),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
