import '../database_helper.dart';

/// Base mixin providing audit column fields shared by all models.
mixin AuditFields {
  late int? id;
  late String createdAt;
  late String? createdBy;
  late String? createdIp;
  late String modifiedAt;
  late String? modifiedBy;
  late String? modifiedIp;
  late int invalidated;

  void loadAudit(Map<String, dynamic> map) {
    id = map['id'] as int?;
    createdAt = map['created_at'] as String? ?? '';
    createdBy = map['created_by'] as String?;
    createdIp = map['created_ip'] as String?;
    modifiedAt = map['modified_at'] as String? ?? '';
    modifiedBy = map['modified_by'] as String?;
    modifiedIp = map['modified_ip'] as String?;
    invalidated = map['invalidated'] as int? ?? DatabaseHelper.statusActive;
  }

  Map<String, dynamic> auditToMap() => {
        if (id != null) 'id': id,
        'created_at': createdAt,
        'created_by': createdBy,
        'created_ip': createdIp,
        'modified_at': modifiedAt,
        'modified_by': modifiedBy,
        'modified_ip': modifiedIp,
        'invalidated': invalidated,
      };

  void initAuditDefaults() {
    final now = DateTime.now().toIso8601String();
    id = null;
    createdAt = now;
    createdBy = null;
    createdIp = null;
    modifiedAt = now;
    modifiedBy = null;
    modifiedIp = null;
    invalidated = DatabaseHelper.statusActive;
  }
}
