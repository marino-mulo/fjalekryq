import 'audit_fields.dart';

class DailyPuzzleModel with AuditFields {
  int userId;
  String date;
  String puzzleJson;
  String? gridJson;
  int solved;
  int swapsUsed;
  int hintCount;
  int totalSwapCount;

  DailyPuzzleModel({
    int? id,
    required this.userId,
    required this.date,
    required this.puzzleJson,
    this.gridJson,
    this.solved = 0,
    this.swapsUsed = 0,
    this.hintCount = 0,
    this.totalSwapCount = 0,
  }) {
    initAuditDefaults();
    this.id = id;
  }

  factory DailyPuzzleModel.fromMap(Map<String, dynamic> map) {
    final model = DailyPuzzleModel(
      userId: map['user_id'] as int,
      date: map['date'] as String,
      puzzleJson: map['puzzle_json'] as String,
      gridJson: map['grid_json'] as String?,
      solved: map['solved'] as int? ?? 0,
      swapsUsed: map['swaps_used'] as int? ?? 0,
      hintCount: map['hint_count'] as int? ?? 0,
      totalSwapCount: map['total_swap_count'] as int? ?? 0,
    );
    model.loadAudit(map);
    return model;
  }

  Map<String, dynamic> toMap() => {
        ...auditToMap(),
        'user_id': userId,
        'date': date,
        'puzzle_json': puzzleJson,
        'grid_json': gridJson,
        'solved': solved,
        'swaps_used': swapsUsed,
        'hint_count': hintCount,
        'total_swap_count': totalSwapCount,
      };
}
