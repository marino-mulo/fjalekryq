using LojraLogjike.Api.Generation;

namespace LojraLogjike.Api.Games.Tango;

/// <summary>
/// Provides auto-generated Tango puzzles with unique solutions.
/// Puzzles are deterministic: same day → same puzzle for everyone.
/// Uses week start (Monday) + day index as the seed.
/// </summary>
public static class TangoPuzzleData
{
    private static readonly string[] DayNames =
        ["E Hënë", "E Martë", "E Mërkurë", "E Enjte", "E Premte", "E Shtunë", "E Diel"];

    // Cache generated puzzles for the current week to avoid regenerating on each request
    private static readonly Dictionary<string, TangoPuzzle> Cache = new();
    private static readonly object CacheLock = new();

    public static TangoPuzzle GetTodayPuzzle()
    {
        var dayOfWeek = (int)DateTime.Now.DayOfWeek;
        var index = dayOfWeek == 0 ? 6 : dayOfWeek - 1;
        return GetPuzzleByDay(index);
    }

    public static TangoPuzzle GetPuzzleByDay(int dayIndex)
    {
        if (dayIndex < 0 || dayIndex > 6)
            dayIndex = 0;

        var weekKey = GetWeekKey();
        var cacheKey = $"{weekKey}_{dayIndex}";

        lock (CacheLock)
        {
            if (Cache.TryGetValue(cacheKey, out var cached))
                return ClonePuzzle(cached, dayIndex);

            // Clean stale cache entries from previous weeks
            var staleKeys = Cache.Keys.Where(k => !k.StartsWith(weekKey)).ToList();
            foreach (var key in staleKeys)
                Cache.Remove(key);
        }

        // Try loading from pre-generated file first
        var puzzle = PuzzleFileStore.LoadPuzzle<TangoPuzzle>(weekKey, "tango", dayIndex);

        // Fallback: generate on-the-fly
        if (puzzle == null)
        {
            var seed = ComputeSeed(weekKey, dayIndex);
            var dayName = DayNames[dayIndex];
            puzzle = TangoGenerator.Generate(seed, dayIndex, dayName);
        }

        lock (CacheLock)
        {
            Cache[cacheKey] = puzzle;
        }

        return ClonePuzzle(puzzle, dayIndex);
    }

    /// <summary>
    /// Get the Monday of the current week as a string key (e.g., "2026-02-23").
    /// </summary>
    private static string GetWeekKey()
    {
        var now = DateTime.Now;
        var day = now.DayOfWeek;
        var diff = day == DayOfWeek.Sunday ? -6 : -(int)day + 1;
        var monday = now.AddDays(diff);
        return $"{monday.Year}-{monday.Month:D2}-{monday.Day:D2}";
    }

    /// <summary>
    /// Compute a deterministic seed from the week key and day index.
    /// Same week + same day = same seed = same puzzle for everyone.
    /// </summary>
    private static int ComputeSeed(string weekKey, int dayIndex)
    {
        // Simple but effective: hash the string and mix with day index
        var hash = weekKey.GetHashCode(StringComparison.Ordinal);
        return hash ^ (dayIndex * 7919); // 7919 is a prime for mixing
    }

    /// <summary>
    /// Return a copy so callers can't mutate the cached puzzle.
    /// </summary>
    private static TangoPuzzle ClonePuzzle(TangoPuzzle source, int dayIndex)
    {
        return new TangoPuzzle
        {
            Solution = source.Solution.Select(r => (int[])r.Clone()).ToArray(),
            Prefilled = source.Prefilled.Select(r => (int[])r.Clone()).ToArray(),
            Constraints = source.Constraints.Select(c => new TangoConstraint
            {
                R1 = c.R1, C1 = c.C1, R2 = c.R2, C2 = c.C2, Type = c.Type
            }).ToArray(),
            DayIndex = dayIndex,
            DayName = DayNames[dayIndex]
        };
    }
}
