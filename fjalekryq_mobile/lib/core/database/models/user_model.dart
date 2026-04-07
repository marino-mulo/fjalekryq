import 'audit_fields.dart';

class UserModel with AuditFields {
  String username;
  String? email;
  String? avatar;

  UserModel({
    int? id,
    required this.username,
    this.email,
    this.avatar,
  }) {
    initAuditDefaults();
    this.id = id;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final user = UserModel(
      username: map['username'] as String,
      email: map['email'] as String?,
      avatar: map['avatar'] as String?,
    );
    user.loadAudit(map);
    return user;
  }

  Map<String, dynamic> toMap() => {
        ...auditToMap(),
        'username': username,
        'email': email,
        'avatar': avatar,
      };
}
