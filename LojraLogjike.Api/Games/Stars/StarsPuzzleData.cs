using LojraLogjike.Api.Generation;

namespace LojraLogjike.Api.Games.Stars;

/// <summary>
/// Provides auto-generated Stars puzzles with unique solutions.
/// Puzzles are deterministic: same day → same puzzle for everyone.
/// Uses week start (Monday) + day index as the seed.
/// </summary>
public static class StarsPuzzleData
{
    private static readonly string[] DayNames =
        ["E Hënë", "E Martë", "E Mërkurë", "E Enjte", "E Premte", "E Shtunë", "E Diel"];

    private static readonly Dictionary<string, StarsPuzzle> Cache = new();
    private static readonly object CacheLock = new();

    public static StarsPuzzle GetTodayPuzzle()
    {
        var dayOfWeek = (int)DateTime.Now.DayOfWeek;
        var index = dayOfWeek == 0 ? 6 : dayOfWeek - 1;
        return GetPuzzleByDay(index);
    }

    public static StarsPuzzle GetPuzzleByDay(int dayIndex)
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
        var puzzle = PuzzleFileStore.LoadPuzzle<StarsPuzzle>(weekKey, "stars", dayIndex);

        // Fallback: generate on-the-fly
        if (puzzle == null)
        {
            var seed = ComputeSeed(weekKey, dayIndex);
            var dayName = DayNames[dayIndex];
            puzzle = StarsGenerator.Generate(seed, dayIndex, dayName);
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

    private static StarsPuzzle ClonePuzzle(StarsPuzzle source, int dayIndex)
    {
        return new StarsPuzzle
        {
            Size = source.Size,
            Zones = source.Zones.Select(r => (int[])r.Clone()).ToArray(),
            Solution = source.Solution.Select(r => (int[])r.Clone()).ToArray(),
            DayIndex = dayIndex,
            DayName = DayNames[dayIndex]
        };
    }
}
