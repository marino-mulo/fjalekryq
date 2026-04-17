import 'package:shared_preferences/shared_preferences.dart';

/// A once-per-day discounted bundle surfaced as a floating banner on the
/// home screen and bought via a confirm modal in the shop.
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

/// The rotating pool. Picking one per day via [offerForToday] keeps all three
/// price points reachable across the week.
const List<DailyOffer> dailyOfferPool = [
  DailyOffer(id: 'daily_099', price: '\$0.99', coins: 150, hints: 1),
  DailyOffer(id: 'daily_199', price: '\$1.99', coins: 400, hints: 2),
  DailyOffer(id: 'daily_299', price: '\$2.99', coins: 800, hints: 4),
];

const _dismissedDateKey = 'fjalekryq_daily_offer_dismissed_date';

String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Deterministic pick based on days-since-epoch → same offer all day, rotates
/// at midnight.
DailyOffer offerForToday() {
  final daysSinceEpoch = DateTime.now().toUtc().difference(DateTime.utc(1970, 1, 1)).inDays;
  return dailyOfferPool[daysSinceEpoch % dailyOfferPool.length];
}

/// Whether the user dismissed today's offer by tapping the close button.
bool isDismissedToday(SharedPreferences prefs) {
  return prefs.getString(_dismissedDateKey) == _todayKey();
}

Future<void> markDismissedToday(SharedPreferences prefs) {
  return prefs.setString(_dismissedDateKey, _todayKey());
}
