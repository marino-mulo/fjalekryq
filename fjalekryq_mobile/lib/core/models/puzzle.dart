/// Direction of a word in the crossword grid.
enum WordDirection { horizontal, vertical }

/// A single word placed in the crossword grid.
class WordEntry {
  final String word;
  final int row;
  final int col;
  final WordDirection direction;

  const WordEntry({
    required this.word,
    required this.row,
    required this.col,
    required this.direction,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'row': row,
        'col': col,
        'direction': direction == WordDirection.horizontal ? 'horizontal' : 'vertical',
      };

  factory WordEntry.fromJson(Map<String, dynamic> json) => WordEntry(
        word: json['word'] as String,
        row: json['row'] as int,
        col: json['col'] as int,
        direction: json['direction'] == 'horizontal'
            ? WordDirection.horizontal
            : WordDirection.vertical,
      );
}

/// A complete puzzle with solution grid, word list, and swap limit.
class Wordle7Puzzle {
  final int gridSize;
  final List<List<String>> solution;
  final List<WordEntry> words;
  final int swapLimit;
  final String hash;

  const Wordle7Puzzle({
    required this.gridSize,
    required this.solution,
    required this.words,
    required this.swapLimit,
    this.hash = '',
  });

  Map<String, dynamic> toJson() => {
        'gridSize': gridSize,
        'solution': solution.map((r) => r.toList()).toList(),
        'words': words.map((w) => w.toJson()).toList(),
        'swapLimit': swapLimit,
        'hash': hash,
      };

  factory Wordle7Puzzle.fromJson(Map<String, dynamic> json) => Wordle7Puzzle(
        gridSize: json['gridSize'] as int,
        solution: (json['solution'] as List)
            .map((r) => (r as List).map((c) => c as String).toList())
            .toList(),
        words: (json['words'] as List)
            .map((w) => WordEntry.fromJson(w as Map<String, dynamic>))
            .toList(),
        swapLimit: json['swapLimit'] as int,
        hash: json['hash'] as String? ?? '',
      );
}
