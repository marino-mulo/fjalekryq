using System.Collections.Concurrent;

namespace Fjalekryq.Api.Games.Wordle7;

/// <summary>
/// Singleton that pre-generates one puzzle per level at startup so that
/// the GET /api/puzzles/wordle7/level/{level} endpoint returns instantly.
/// </summary>
public class LevelPuzzleStore
{
    // difficulty per level (1-indexed, mirrors level-map NODES)
    private static readonly string[] LevelDifficulties =
    [
        "easy", "easy", "easy",         // levels 1-3
        "medium", "medium", "medium",   // levels 4-6
        "hard", "hard", "hard",         // levels 7-9
        "expert",                        // level 10
    ];

    private readonly ConcurrentDictionary<int, LevelEntry> _store = new();

    public record LevelEntry(Wordle7Puzzle Puzzle, string Hash, int SwapLimit, string Difficulty);

    public LevelPuzzleStore()
    {
        GenerateAll();
    }

    public LevelEntry? Get(int level) =>
        _store.TryGetValue(level, out var e) ? e : null;

    public void Regenerate(int level)
    {
        var difficulty = GetDifficulty(level);
        _store[level] = Build(level, difficulty);
    }

    private void GenerateAll()
    {
        // Use Parallel.For so all 10 puzzles generate concurrently
        Parallel.For(1, 11, level =>
        {
            var difficulty = GetDifficulty(level);
            _store[level] = Build(level, difficulty);
        });
    }

    private static LevelEntry Build(int level, string difficulty)
    {
        // Fixed seed per level so the puzzle is stable for the lifetime of the process.
        // Seed mixes the level number with a constant to spread the seed space.
        var seed = level * 99_991 + 42_013;
        var puzzle = Wordle7Generator.GenerateRandom(seed, excludeWords: null, difficulty);
        var hash   = Wordle7Generator.ComputePuzzleHash(puzzle.Solution);

        var filledCells = puzzle.Solution.Sum(row => row.Count(c => c != "X"));
        var swapLimit = difficulty switch
        {
            "easy"   => (int)Math.Ceiling(filledCells * 0.65) + 5,
            "medium" => (int)Math.Ceiling(filledCells * 0.65) + 7,
            "hard"   => (int)Math.Ceiling(filledCells * 0.65) + 10,
            "expert" => (int)Math.Ceiling(filledCells * 0.65) + 12,
            _        => (int)Math.Ceiling(filledCells * 0.65) + 7,
        };

        return new LevelEntry(puzzle, hash, swapLimit, difficulty);
    }

    private static string GetDifficulty(int level) =>
        level >= 1 && level <= LevelDifficulties.Length
            ? LevelDifficulties[level - 1]
            : "medium";
}
