import 'package:shared_preferences/shared_preferences.dart';

/// A discounted bundle surfaced as a floating banner on the home screen and
/// bought via a confirm modal in the shop.
class DailyOffer {
  final String id;
  final String price;
  final int coins;
  final int hints;

  const DailyOffer({
    required this.id,
    required this.price,
    required this.coins,
    required this.hints,
  });
}

/// Tiered offer pool — the user is walked up the ladder: after buying
/// tier 0 ($0.99) the shop surfaces tier 1 ($1.99), then tier 2 ($2.99).
/// Once tier 2 is bought the shop stays on tier 2.
const List<DailyOffer> dailyOfferPool = [
  DailyOffer(id: 'daily_099', price: '\$0.99', coins: 150, hints: 1),
  DailyOffer(id: 'daily_199', price: '\$1.99', coins: 400, hints: 2),
  DailyOffer(id: 'daily_299', price: '\$2.99', coins: 800, hints: 4),
];

const _offerTierKey = 'fjalekryq_daily_offer_tier';

/// Read the current offer tier from prefs (0-indexed, clamped to pool).
int _currentTier(SharedPreferences prefs) {
  final raw = prefs.getInt(_offerTierKey) ?? 0;
  if (raw < 0) return 0;
  if (raw >= dailyOfferPool.length) return dailyOfferPool.length - 1;
  return raw;
}

/// Return the offer the user should see right now. Fallback to tier 0 when
/// prefs are unavailable.
DailyOffer offerForPrefs(SharedPreferences? prefs) {
  if (prefs == null) return dailyOfferPool[0];
  return dailyOfferPool[_currentTier(prefs)];
}

/// Advance to the next tier after a successful purchase. Caps at the last
/// tier — subsequent buys keep surfacing the top-tier offer.
Future<void> advanceOfferTier(SharedPreferences prefs) async {
  final next = _currentTier(prefs) + 1;
  final clamped = next >= dailyOfferPool.length
      ? dailyOfferPool.length - 1
      : next;
  await prefs.setInt(_offerTierKey, clamped);
}
