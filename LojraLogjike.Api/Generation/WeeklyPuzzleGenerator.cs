using System.Diagnostics;
using LojraLogjike.Api.Games.Wordle7;

namespace LojraLogjike.Api.Generation;

/// <summary>
/// Orchestrates weekly puzzle generation for Fjalëkryq (wordle7).
/// Generates 7 puzzles (Mon-Sun) and saves them as JSON files.
/// Ensures no duplicate puzzles across weeks via solution hashing.
/// </summary>
public static class WeeklyPuzzleGenerator
{
    private static readonly string[] GameNames = ["wordle7"];

    private static readonly string[] DayNames =
        ["E Hënë", "E Martë", "E Mërkurë", "E Enjte", "E Premte", "E Shtunë", "E Diel"];

    private static readonly string[] DayLabels =
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    private static readonly Dictionary<string, Func<int, int, string, object>> Generators = new()
    {
        ["wordle7"] = (seed, di, dn) => Wordle7Generator.Generate(seed, di, dn),
    };

    public static async Task GenerateWeek(string? weekKeyOverride = null)
    {
        var sw = Stopwatch.StartNew();

        var weekKey = weekKeyOverride ?? GetNextMondayKey();
        var monday = DateTime.ParseExact(weekKey, "yyyy-MM-dd", null);
        var sunday = monday.AddDays(6);

        Console.WriteLine();
        Console.WriteLine($"  Generating puzzles for week {weekKey}");
        Console.WriteLine($"  {monday:ddd dd MMM yyyy} — {sunday:ddd dd MMM yyyy}");
        Console.WriteLine($"  ════════════════════════════════════════════════");
        Console.WriteLine();

        var hashes = PuzzleFileStore.LoadHashes();
        var totalGenerated = 0;
        var totalRetries = 0;

        foreach (var game in GameNames)
        {
            if (!hashes.ContainsKey(game))
                hashes[game] = new HashSet<string>();

            for (var dayIndex = 0; dayIndex < 7; dayIndex++)
            {
                var dayName = DayNames[dayIndex];
                var dayLabel = DayLabels[dayIndex];

                var existingFile = PuzzleFileStore.LoadPuzzle<object>(weekKey, game, dayIndex);
                if (existingFile != null)
                {
                    Console.WriteLine($"  [{game,-8}]  Day {dayIndex} ({dayLabel})  ... SKIP (already exists)");
                    continue;
                }

                var baseSeed = ComputeSeed(weekKey, dayIndex);

                object? puzzle = null;
                string? hash = null;
                var retries = 0;

                for (var offset = 0; offset < 100; offset++)
                {
                    var seed = baseSeed + offset * 31337;

                    try
                    {
                        puzzle = Generators[game](seed, dayIndex, dayName);
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"  [{game,-8}]  Day {dayIndex} ({dayLabel})  ... FAIL: {ex.Message}");
                        puzzle = null;
                        break;
                    }

                    hash = PuzzleHasher.ComputeHash(game, puzzle);

                    if (!hashes[game].Contains(hash))
                    {
                        retries = offset;
                        break;
                    }

                    puzzle = null;
                    retries = offset + 1;
                }

                if (puzzle == null || hash == null)
                {
                    Console.WriteLine($"  [{game,-8}]  Day {dayIndex} ({dayLabel})  ... FAIL (no unique puzzle after {retries} retries)");
                    continue;
                }

                PuzzleFileStore.SavePuzzle(weekKey, game, dayIndex, puzzle);
                hashes[game].Add(hash);

                totalGenerated++;
                totalRetries += retries;

                var retryNote = retries > 0 ? $"  [dedup: retry {retries}]" : "";
                Console.WriteLine($"  [{game,-8}]  Day {dayIndex} ({dayLabel})  ... OK{retryNote}");
            }

            Console.WriteLine();
        }

        PuzzleFileStore.SaveHashes(hashes);

        sw.Stop();

        var totalHashes = hashes.Values.Sum(h => h.Count);

        Console.WriteLine($"  ════════════════════════════════════════════════");
        Console.WriteLine($"  Generated {totalGenerated} puzzles in {sw.Elapsed.TotalSeconds:F1}s");
        if (totalRetries > 0)
            Console.WriteLine($"  Dedup retries: {totalRetries}");
        Console.WriteLine($"  Output: Puzzles/{weekKey}/");
        Console.WriteLine($"  Hashes: {totalHashes} unique solutions tracked");
        Console.WriteLine();

        await Task.CompletedTask;
    }

    private static string GetNextMondayKey()
    {
        var now = DateTime.Now;
        var daysUntilMonday = ((int)DayOfWeek.Monday - (int)now.DayOfWeek + 7) % 7;
        if (daysUntilMonday == 0) daysUntilMonday = 7;
        var monday = now.AddDays(daysUntilMonday);
        return $"{monday.Year}-{monday.Month:D2}-{monday.Day:D2}";
    }

    private static int ComputeSeed(string weekKey, int dayIndex)
    {
        var hash = weekKey.GetHashCode(StringComparison.Ordinal);
        return hash ^ (dayIndex * 7919);
    }
}
