import 'audit_fields.dart';

class ProgressModel with AuditFields {
  int userId;
  int level;
  int completed;

  ProgressModel({
    int? id,
    required this.userId,
    required this.level,
    this.completed = 0,
  }) {
    initAuditDefaults();
    this.id = id;
  }

  factory ProgressModel.fromMap(Map<String, dynamic> map) {
    final model = ProgressModel(
      userId: map['user_id'] as int,
      level: map['level'] as int,
      completed: map['completed'] as int? ?? 0,
    );
    model.loadAudit(map);
    return model;
  }

  Map<String, dynamic> toMap() => {
        ...auditToMap(),
        'user_id': userId,
        'level': level,
        'completed': completed,
      };
}
