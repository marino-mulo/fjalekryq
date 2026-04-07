import 'audit_fields.dart';

class CoinsModel with AuditFields {
  int userId;
  int balance;
  String? lastDailyClaim;
  int streakDay;

  CoinsModel({
    int? id,
    required this.userId,
    this.balance = 100,
    this.lastDailyClaim,
    this.streakDay = 0,
  }) {
    initAuditDefaults();
    this.id = id;
  }

  factory CoinsModel.fromMap(Map<String, dynamic> map) {
    final model = CoinsModel(
      userId: map['user_id'] as int,
      balance: map['balance'] as int? ?? 100,
      lastDailyClaim: map['last_daily_claim'] as String?,
      streakDay: map['streak_day'] as int? ?? 0,
    );
    model.loadAudit(map);
    return model;
  }

  Map<String, dynamic> toMap() => {
        ...auditToMap(),
        'user_id': userId,
        'balance': balance,
        'last_daily_claim': lastDailyClaim,
        'streak_day': streakDay,
      };
}
