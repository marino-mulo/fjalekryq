import 'audit_fields.dart';

class LevelModel with AuditFields {
  int level;
  String difficulty;
  int coinsToEarn;
  int seed;

  LevelModel({
    int? id,
    required this.level,
    required this.difficulty,
    required this.coinsToEarn,
    required this.seed,
  }) {
    initAuditDefaults();
    this.id = id;
  }

  factory LevelModel.fromMap(Map<String, dynamic> map) {
    final model = LevelModel(
      level: map['level'] as int,
      difficulty: map['difficulty'] as String,
      coinsToEarn: map['coins_to_earn'] as int,
      seed: map['seed'] as int? ?? 0,
    );
    model.loadAudit(map);
    return model;
  }

  Map<String, dynamic> toMap() => {
        ...auditToMap(),
        'level': level,
        'difficulty': difficulty,
        'coins_to_earn': coinsToEarn,
        'seed': seed,
      };
}
