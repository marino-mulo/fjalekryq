import 'audit_fields.dart';

class SettingsModel with AuditFields {
  int userId;
  bool music;
  bool sound;
  bool notification;
  bool emailNotification;

  SettingsModel({
    int? id,
    required this.userId,
    this.music = true,
    this.sound = true,
    this.notification = true,
    this.emailNotification = true,
  }) {
    initAuditDefaults();
    this.id = id;
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    final model = SettingsModel(
      userId: map['user_id'] as int,
      music: (map['music'] as int? ?? 1) == 1,
      sound: (map['sound'] as int? ?? 1) == 1,
      notification: (map['notification'] as int? ?? 1) == 1,
      emailNotification: (map['email_notification'] as int? ?? 1) == 1,
    );
    model.loadAudit(map);
    return model;
  }

  Map<String, dynamic> toMap() => {
        ...auditToMap(),
        'user_id': userId,
        'music': music ? 1 : 0,
        'sound': sound ? 1 : 0,
        'notification': notification ? 1 : 0,
        'email_notification': emailNotification ? 1 : 0,
      };
}
