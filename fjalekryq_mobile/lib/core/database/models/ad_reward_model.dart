import 'audit_fields.dart';

class AdRewardModel with AuditFields {
  int userId;
  String type;
  String? claimedAt;

  AdRewardModel({
    int? id,
    required this.userId,
    required this.type,
    this.claimedAt,
  }) {
    initAuditDefaults();
    this.id = id;
  }

  factory AdRewardModel.fromMap(Map<String, dynamic> map) {
    final model = AdRewardModel(
      userId: map['user_id'] as int,
      type: map['type'] as String,
      claimedAt: map['claimed_at'] as String?,
    );
    model.loadAudit(map);
    return model;
  }

  Map<String, dynamic> toMap() => {
        ...auditToMap(),
        'user_id': userId,
        'type': type,
        'claimed_at': claimedAt,
      };
}
