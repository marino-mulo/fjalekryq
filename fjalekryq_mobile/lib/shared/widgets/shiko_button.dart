import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Unified "Shiko" (watch ad) button used across the entire app.
///
/// Three variants controlled by [size]:
/// - [ShikoSize.small]  — tiny pill badge (e.g. on control buttons)
/// - [ShikoSize.medium] — inline pill (e.g. in banners, win/loss screens)
/// - [ShikoSize.large]  — full-width row with icon + text (e.g. in shop, daily reward)

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

  @override
  Widget build(BuildContext context) {
    switch (size) {
      case ShikoSize.small:
        return _buildSmall();
      case ShikoSize.medium:
        return _buildMedium();
      case ShikoSize.large:
        return _buildLarge();
    }
  }

  /// Tiny pill badge — e.g. "▶ Shiko" on control buttons
  Widget _buildSmall() {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.purpleAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: AppColors.purpleAccent.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(color: AppColors.purpleAccent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: loading
            ? const SizedBox(
                width: 10, height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFE2C9FF)),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow, color: Color(0xFFE2C9FF), size: 10),
                  const SizedBox(width: 3),
                  Text(
                    label ?? 'Shiko',
                    style: AppFonts.nunito(
                      color: const Color(0xFFE2C9FF),
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
  Widget _buildMedium() {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.purpleAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.purpleAccent.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(color: AppColors.purpleAccent.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            child: loading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFE2C9FF)),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow, color: Color(0xFFE2C9FF), size: 13),
                      const SizedBox(width: 5),
                      Text(
                        label ?? 'Shiko',
                        style: AppFonts.nunito(
                          color: const Color(0xFFE2C9FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
          ),
          if (badge != null)
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
  Widget _buildLarge() {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.purpleAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.purpleAccent.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(color: AppColors.purpleAccent.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE2C9FF)),
              )
            else
              const Icon(Icons.play_arrow, color: Color(0xFFE2C9FF), size: 18),
            const SizedBox(width: 8),
            Text(
              label ?? 'Shiko reklamë',
              style: AppFonts.nunito(
                color: const Color(0xFFE2C9FF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
