import 'audit_fields.dart';

class LevelModel with AuditFields {
  int level;
  String difficulty;
  int coinsToEarn;

  LevelModel({
    int? id,
    required this.level,
    required this.difficulty,
    required this.coinsToEarn,
  }) {
    initAuditDefaults();
    this.id = id;
  }

  factory LevelModel.fromMap(Map<String, dynamic> map) {
    final model = LevelModel(
      level: map['level'] as int,
      difficulty: map['difficulty'] as String,
      coinsToEarn: map['coins_to_earn'] as int,
    );
    model.loadAudit(map);
    return model;
  }

  Map<String, dynamic> toMap() => {
        ...auditToMap(),
        'level': level,
        'difficulty': difficulty,
        'coins_to_earn': coinsToEarn,
      };
}
