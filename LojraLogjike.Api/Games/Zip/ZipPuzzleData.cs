using LojraLogjike.Api.Generation;

namespace LojraLogjike.Api.Games.Zip;

/// <summary>
/// Provides auto-generated Zip puzzles with unique solutions.
/// Puzzles are deterministic: same day → same puzzle for everyone.
/// Uses week start (Monday) + day index as the seed.
/// </summary>
public static class ZipPuzzleData
{
    private static readonly string[] DayNames =
        ["E Hënë", "E Martë", "E Mërkurë", "E Enjte", "E Premte", "E Shtunë", "E Diel"];

    private static readonly Dictionary<string, ZipPuzzle> Cache = new();
    private static readonly object CacheLock = new();

    public static ZipPuzzle GetTodayPuzzle()
    {
        var dayOfWeek = (int)DateTime.Now.DayOfWeek;
        var index = dayOfWeek == 0 ? 6 : dayOfWeek - 1;
        return GetPuzzleByDay(index);
    }

    public static ZipPuzzle GetPuzzleByDay(int dayIndex)
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
        var puzzle = PuzzleFileStore.LoadPuzzle<ZipPuzzle>(weekKey, "zip", dayIndex);

        // Fallback: generate on-the-fly
        if (puzzle == null)
        {
            var seed = ComputeSeed(weekKey, dayIndex);
            var dayName = DayNames[dayIndex];
            puzzle = ZipGenerator.Generate(seed, dayIndex, dayName);
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

    private static ZipPuzzle ClonePuzzle(ZipPuzzle source, int dayIndex)
    {
        return new ZipPuzzle
        {
            Rows = source.Rows,
            Cols = source.Cols,
            Numbers = new Dictionary<int, int>(source.Numbers),
            Walls = source.Walls.Select(w => (int[])w.Clone()).ToArray(),
            SolutionPath = (int[])source.SolutionPath.Clone(),
            DayIndex = dayIndex,
            DayName = DayNames[dayIndex]
        };
    }
}
