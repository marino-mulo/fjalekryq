/// A server-generated puzzle cached locally so the user can replay
/// levels they've already fetched even when offline.
class UserGeneratedLevelModel {
  final int? id;
  final int userId;
  final int level;
  final String difficulty;
  final String puzzleJson;

  const UserGeneratedLevelModel({
    this.id,
    required this.userId,
    required this.level,
    required this.difficulty,
    required this.puzzleJson,
  });

  factory UserGeneratedLevelModel.fromMap(Map<String, dynamic> map) =>
      UserGeneratedLevelModel(
        id:         map['id']           as int?,
        userId:     map['user_id']      as int,
        level:      map['level']        as int,
        difficulty: map['difficulty']   as String,
        puzzleJson: map['puzzle_json']  as String,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id':     userId,
        'level':       level,
        'difficulty':  difficulty,
        'puzzle_json': puzzleJson,
      };
}
