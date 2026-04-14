import 'audit_fields.dart';

class DailyStreakModel with AuditFields {
  int userId;
  int currentStreak;
  int bestStreak;
  String? lastSolvedDate;
  String? frozenUntil;

  DailyStreakModel({
    int? id,
    required this.userId,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastSolvedDate,
    this.frozenUntil,
  }) {
    initAuditDefaults();
    this.id = id;
  }

  factory DailyStreakModel.fromMap(Map<String, dynamic> map) {
    final model = DailyStreakModel(
      userId: map['user_id'] as int,
      currentStreak: map['current_streak'] as int? ?? 0,
      bestStreak: map['best_streak'] as int? ?? 0,
      lastSolvedDate: map['last_solved_date'] as String?,
      frozenUntil: map['frozen_until'] as String?,
    );
    model.loadAudit(map);
    return model;
  }

  Map<String, dynamic> toMap() => {
        ...auditToMap(),
        'user_id': userId,
        'current_streak': currentStreak,
        'best_streak': bestStreak,
        'last_solved_date': lastSolvedDate,
        'frozen_until': frozenUntil,
      };
}
