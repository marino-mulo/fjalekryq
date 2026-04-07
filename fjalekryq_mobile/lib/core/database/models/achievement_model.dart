import 'audit_fields.dart';

class AchievementModel with AuditFields {
  int userId;
  String achievementId;
  String? unlockedAt;

  AchievementModel({
    int? id,
    required this.userId,
    required this.achievementId,
    this.unlockedAt,
  }) {
    initAuditDefaults();
    this.id = id;
  }

  factory AchievementModel.fromMap(Map<String, dynamic> map) {
    final model = AchievementModel(
      userId: map['user_id'] as int,
      achievementId: map['achievement_id'] as String,
      unlockedAt: map['unlocked_at'] as String?,
    );
    model.loadAudit(map);
    return model;
  }

  Map<String, dynamic> toMap() => {
        ...auditToMap(),
        'user_id': userId,
        'achievement_id': achievementId,
        'unlocked_at': unlockedAt,
      };
}
