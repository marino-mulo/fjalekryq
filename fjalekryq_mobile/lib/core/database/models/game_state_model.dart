import 'audit_fields.dart';

class GameStateModel with AuditFields {
  int userId;
  int level;
  String gridJson;
  int swapsUsed;
  String? hintCooldown;

  GameStateModel({
    int? id,
    required this.userId,
    required this.level,
    required this.gridJson,
    this.swapsUsed = 0,
    this.hintCooldown,
  }) {
    initAuditDefaults();
    this.id = id;
  }

  factory GameStateModel.fromMap(Map<String, dynamic> map) {
    final model = GameStateModel(
      userId: map['user_id'] as int,
      level: map['level'] as int,
      gridJson: map['grid_json'] as String,
      swapsUsed: map['swaps_used'] as int? ?? 0,
      hintCooldown: map['hint_cooldown'] as String?,
    );
    model.loadAudit(map);
    return model;
  }

  Map<String, dynamic> toMap() => {
        ...auditToMap(),
        'user_id': userId,
        'level': level,
        'grid_json': gridJson,
        'swaps_used': swapsUsed,
        'hint_cooldown': hintCooldown,
      };
}
