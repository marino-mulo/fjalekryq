using System.Text.Json;

namespace LojraLogjike.Api.Generation;

/// <summary>
/// Handles reading/writing puzzle JSON files and the dedup hashes registry.
/// Puzzles are stored in: Puzzles/{weekKey}/{game}_{dayIndex}.json
/// </summary>
public static class PuzzleFileStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private static readonly JsonSerializerOptions ReadOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    private static string? _puzzlesRoot;

    /// <summary>
    /// Resolves the Puzzles/ directory.
    /// In development: relative to the project root.
    /// In production: relative to the application base directory.
    /// </summary>
    public static string GetPuzzlesDirectory()
    {
        if (_puzzlesRoot != null) return _puzzlesRoot;

        // Try project root first (development)
        var projectDir = Path.Combine(AppContext.BaseDirectory, "..", "..", "..");
        var devPath = Path.GetFullPath(Path.Combine(projectDir, "Puzzles"));
        if (Directory.Exists(devPath))
        {
            _puzzlesRoot = devPath;
            return _puzzlesRoot;
        }

        // Fall back to AppContext.BaseDirectory (production / published)
        var prodPath = Path.Combine(AppContext.BaseDirectory, "Puzzles");
        Directory.CreateDirectory(prodPath);
        _puzzlesRoot = prodPath;
        return _puzzlesRoot;
    }

    /// <summary>
    /// Get the file path for a specific puzzle.
    /// </summary>
    private static string GetPuzzlePath(string weekKey, string gameName, int dayIndex)
    {
        return Path.Combine(GetPuzzlesDirectory(), weekKey, $"{gameName}_{dayIndex}.json");
    }

    /// <summary>
    /// Load a pre-generated puzzle from disk. Returns null if the file doesn't exist.
    /// </summary>
    public static T? LoadPuzzle<T>(string weekKey, string gameName, int dayIndex) where T : class
    {
        var path = GetPuzzlePath(weekKey, gameName, dayIndex);
        if (!File.Exists(path)) return null;

        try
        {
            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<T>(json, ReadOptions);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[PuzzleFileStore] Failed to load {path}: {ex.Message}");
            return null;
        }
    }

    /// <summary>
    /// Save a puzzle to disk as a JSON file.
    /// </summary>
    public static void SavePuzzle<T>(string weekKey, string gameName, int dayIndex, T puzzle)
    {
        var dir = Path.Combine(GetPuzzlesDirectory(), weekKey);
        Directory.CreateDirectory(dir);

        var path = Path.Combine(dir, $"{gameName}_{dayIndex}.json");
        var json = JsonSerializer.Serialize(puzzle, JsonOptions);
        File.WriteAllText(path, json);
    }

    /// <summary>
    /// Load the dedup hash registry from Puzzles/hashes.json.
    /// Returns a dictionary of game name → set of solution hashes.
    /// </summary>
    public static Dictionary<string, HashSet<string>> LoadHashes()
    {
        var path = Path.Combine(GetPuzzlesDirectory(), "hashes.json");
        if (!File.Exists(path))
            return new Dictionary<string, HashSet<string>>();

        try
        {
            var json = File.ReadAllText(path);
            var raw = JsonSerializer.Deserialize<Dictionary<string, string[]>>(json, ReadOptions);
            if (raw == null) return new Dictionary<string, HashSet<string>>();

            var result = new Dictionary<string, HashSet<string>>();
            foreach (var (key, values) in raw)
                result[key] = new HashSet<string>(values);
            return result;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[PuzzleFileStore] Failed to load hashes: {ex.Message}");
            return new Dictionary<string, HashSet<string>>();
        }
    }

    /// <summary>
    /// Save the dedup hash registry to Puzzles/hashes.json.
    /// </summary>
    public static void SaveHashes(Dictionary<string, HashSet<string>> hashes)
    {
        var path = Path.Combine(GetPuzzlesDirectory(), "hashes.json");

        // Convert HashSet to arrays for serialization
        var serializable = new Dictionary<string, string[]>();
        foreach (var (key, values) in hashes)
            serializable[key] = values.ToArray();

        var json = JsonSerializer.Serialize(serializable, JsonOptions);
        File.WriteAllText(path, json);
    }
}
