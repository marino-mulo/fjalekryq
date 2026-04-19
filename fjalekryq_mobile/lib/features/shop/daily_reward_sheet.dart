import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/coin_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/ad_service.dart';
import '../../shared/constants/theme.dart';
import '../../shared/widgets/offline_view.dart';
import '../../shared/widgets/shiko_button.dart';

/// Bottom sheet for daily login reward claiming.
class DailyRewardSheet extends StatefulWidget {
  const DailyRewardSheet({super.key});

  @override
  State<DailyRewardSheet> createState() => _DailyRewardSheetState();
}

class _DailyRewardSheetState extends State<DailyRewardSheet> {
  ({int amount, int day})? _claimedReward;
  bool _doubled = false;
  bool _loadingAd = false;

  @override
  Widget build(BuildContext context) {
    final coinService = context.watch<CoinService>();
    final dailyAvailable = coinService.peekDaily() != null;
    final currentDay = coinService.currentStreakDay;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              const Icon(Icons.card_giftcard, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Bonus Ditor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white54, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Hyr çdo ditë radhazi dhe merr shpërblime më të mëdha!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),

          // 7-day streak row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final dayNum = index + 1;
              final isClaimed = dayNum < currentDay ||
                  (dayNum == currentDay && !dailyAvailable);
              final isActive = dayNum == currentDay && dailyAvailable;

              return _StreakCell(
                dayNum: dayNum,
                reward: dailyRewards[index],
                isClaimed: isClaimed,
                isActive: isActive,
              );
            }),
          ),
          const SizedBox(height: 16),

          // Today's reward card
          if (dailyAvailable) ...[
            _buildClaimCard(coinService),
          ] else if (_claimedReward != null) ...[
            _buildClaimedMessage(),
          ] else ...[
            _buildWaitMessage(),
          ],

          const SizedBox(height: 12),

          // Close button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Mbyll',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildClaimCard(CoinService coinService) {
    final peek = coinService.peekDaily()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: AppColors.gold, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+${peek.amount}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                ),
                Text(
                  'Dita ${peek.day} e radhës',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final result = coinService.claimDaily();
              if (result != null) {
                HapticFeedback.mediumImpact();
                context.read<AudioService>().play(Sfx.dailyClaim);
                setState(() => _claimedReward = result);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cellGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Merr!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimedMessage() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cellGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                _doubled
                    ? '+${_claimedReward!.amount * 2} monedha u shtuan! (×2)'
                    : '+${_claimedReward!.amount} monedha u shtuan!',
                style: const TextStyle(
                  color: AppColors.greenAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (!_doubled) ...[
          const SizedBox(height: 8),
          ShikoButton(
            size: ShikoSize.large,
            loading: _loadingAd,
            onTap: _watchAdToDouble,
            label: _loadingAd ? 'Po shfaqet reklama...' : 'Shiko reklamë — dyfisho +${_claimedReward!.amount}',
          ),
        ],
      ],
    );
  }

  void _watchAdToDouble() async {
    final adService = context.read<AdService>();
    final coinService = context.read<CoinService>();
    final audio = context.read<AudioService>();
    final amount = _claimedReward!.amount;

    setState(() => _loadingAd = true);

    final success = await adService.showRewardedAd(
      adType: AdType.dailyDouble,
      onReward: () async {
        coinService.add(amount);
        audio.play(Sfx.coin);
      },
      onOffline: () {
        if (mounted) showOfflineSnack(context);
      },
    );

    if (mounted) {
      setState(() {
        _loadingAd = false;
        if (success) _doubled = true;
      });
    }
  }

  Widget _buildWaitMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, color: Colors.white.withValues(alpha: 0.4), size: 16),
          const SizedBox(width: 8),
          Text(
            'Kthehuni nesër për bonusin e radhës!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCell extends StatelessWidget {
  final int dayNum;
  final int reward;
  final bool isClaimed;
  final bool isActive;

  const _StreakCell({
    required this.dayNum,
    required this.reward,
    required this.isClaimed,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.gold.withValues(alpha: 0.2)
                : isClaimed
                    ? AppColors.cellGreen.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(color: AppColors.gold, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isClaimed)
                const Icon(Icons.check, color: AppColors.greenAccent, size: 16)
              else
                const Icon(Icons.monetization_on, color: AppColors.gold, size: 16),
              Text(
                '$reward',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isClaimed ? Colors.white38 : Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Dita $dayNum',
          style: TextStyle(
            fontSize: 8,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}
