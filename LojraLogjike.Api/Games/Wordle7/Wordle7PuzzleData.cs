using LojraLogjike.Api.Generation;

namespace LojraLogjike.Api.Games.Wordle7;

/// <summary>
/// Provides auto-generated Wordle7 (crossword) puzzles.
/// Puzzles are deterministic: same day → same puzzle for everyone.
/// Uses week start (Monday) + day index as the seed.
/// </summary>
public static class Wordle7PuzzleData
{
    private static readonly string[] DayNames =
        ["E Hënë", "E Martë", "E Mërkurë", "E Enjte", "E Premte", "E Shtunë", "E Diel"];

    private static readonly Dictionary<string, Wordle7Puzzle> Cache = new();
    private static readonly object CacheLock = new();

    public static Wordle7Puzzle GetTodayPuzzle()
    {
        var jsDay = (int)DateTime.Now.DayOfWeek;
        var dayIndex = jsDay == 0 ? 6 : jsDay - 1;
        return GetPuzzleByDay(dayIndex);
    }

    public static Wordle7Puzzle GetPuzzleByDay(int dayIndex)
    {
        if (dayIndex < 0 || dayIndex > 6)
            dayIndex = 0;

        var weekKey = GetWeekKey();
        var cacheKey = $"{weekKey}_{dayIndex}";

        lock (CacheLock)
        {
            if (Cache.TryGetValue(cacheKey, out var cached))
                return ClonePuzzle(cached, dayIndex);

            var staleKeys = Cache.Keys.Where(k => !k.StartsWith(weekKey)).ToList();
            foreach (var key in staleKeys)
                Cache.Remove(key);
        }

        // Try loading from pre-generated file first
        var puzzle = PuzzleFileStore.LoadPuzzle<Wordle7Puzzle>(weekKey, "wordle7", dayIndex);

        // Fallback: generate on-the-fly
        if (puzzle == null)
        {
            var seed = ComputeSeed(weekKey, dayIndex);
            var dayName = DayNames[dayIndex];
            puzzle = Wordle7Generator.Generate(seed, dayIndex, dayName);
        }

        lock (CacheLock)
        {
            Cache[cacheKey] = puzzle;
        }

        return ClonePuzzle(puzzle, dayIndex);
    }

    private static string GetWeekKey()
    {
        var now = DateTime.Now;
        var day = now.DayOfWeek;
        var diff = day == DayOfWeek.Sunday ? -6 : -(int)day + 1;
        var monday = now.AddDays(diff);
        return $"{monday.Year}-{monday.Month:D2}-{monday.Day:D2}";
    }

    private static int ComputeSeed(string weekKey, int dayIndex)
    {
        var hash = weekKey.GetHashCode(StringComparison.Ordinal);
        return hash ^ (dayIndex * 7919);
    }

    private static Wordle7Puzzle ClonePuzzle(Wordle7Puzzle source, int dayIndex)
    {
        return new Wordle7Puzzle
        {
            GridSize = source.GridSize,
            Solution = source.Solution.Select(r => (string[])r.Clone()).ToArray(),
            Words = source.Words.Select(w => new WordEntry
            {
                Word = w.Word, Row = w.Row, Col = w.Col, Direction = w.Direction
            }).ToArray(),
            DayIndex = dayIndex,
            DayName = DayNames[dayIndex]
        };
    }
}
