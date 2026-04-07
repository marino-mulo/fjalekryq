import 'audit_fields.dart';

class NotificationModel with AuditFields {
  int userId;
  String notificationText;
  bool opened;

  NotificationModel({
    int? id,
    required this.userId,
    required this.notificationText,
    this.opened = false,
  }) {
    initAuditDefaults();
    this.id = id;
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    final model = NotificationModel(
      userId: map['user_id'] as int,
      notificationText: map['notification_text'] as String,
      opened: (map['opened'] as int? ?? 0) == 1,
    );
    model.loadAudit(map);
    return model;
  }

  Map<String, dynamic> toMap() => {
        ...auditToMap(),
        'user_id': userId,
        'notification_text': notificationText,
        'opened': opened ? 1 : 0,
      };
}
