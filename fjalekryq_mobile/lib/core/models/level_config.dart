/// Difficulty tier for a level.
enum Difficulty { easy, medium, hard, expert }

/// Maps a level number (1-indexed) to its difficulty.
Difficulty difficultyForLevel(int level) {
  if (level <= 3) return Difficulty.easy;
  if (level <= 6) return Difficulty.medium;
  if (level <= 9) return Difficulty.hard;
  return Difficulty.expert;
}

/// Extended difficulty mapping for levels beyond 10 (future expansion).
Difficulty difficultyForLevelExtended(int level) {
  if (level <= 20) return Difficulty.easy;
  if (level <= 60) return Difficulty.medium;
  if (level <= 120) return Difficulty.hard;
  return Difficulty.expert;
}

/// Human-readable Albanian labels for difficulty.
String difficultyLabel(Difficulty d) {
  switch (d) {
    case Difficulty.easy:
      return 'E lehtë';
    case Difficulty.medium:
      return 'Mesatare';
    case Difficulty.hard:
      return 'E vështirë';
    case Difficulty.expert:
      return 'Ekspert';
  }
}

/// Coins earned per difficulty on first clear.
int coinsForDifficulty(Difficulty d) {
  switch (d) {
    case Difficulty.easy:
      return 20;
    case Difficulty.medium:
      return 35;
    case Difficulty.hard:
      return 50;
    case Difficulty.expert:
      return 80;
  }
}

/// Total number of active levels.
const int totalActiveLevels = 10;

/// Total level slots shown in the map.
const int totalMapLevels = 500;

/// Number of locked levels visible after the current level.
const int visibleLockedLevels = 5;
