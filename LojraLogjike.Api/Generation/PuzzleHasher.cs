using System.Security.Cryptography;
using System.Text;
using LojraLogjike.Api.Games.Wordle7;

namespace LojraLogjike.Api.Generation;

/// <summary>
/// Computes SHA256 hashes of puzzle solutions for deduplication.
/// Only the solution data is hashed (not metadata like dayIndex/dayName).
/// </summary>
public static class PuzzleHasher
{
    /// <summary>
    /// Compute a SHA256 hash of the puzzle's solution, keyed by game name.
    /// </summary>
    public static string ComputeHash(string gameName, object puzzle)
    {
        var fingerprint = gameName switch
        {
            "wordle7" => GetWordle7Fingerprint((Wordle7Puzzle)puzzle),
            _ => throw new ArgumentException($"Unknown game: {gameName}")
        };

        return Sha256Hex(fingerprint);
    }

    private static string GetWordle7Fingerprint(Wordle7Puzzle p)
    {
        var sol = string.Join(";", p.Solution.Select(row => string.Join(",", row)));
        var words = string.Join(";", p.Words.Select(w => $"{w.Word},{w.Row},{w.Col},{w.Direction}"));
        return $"{p.GridSize}:{sol}|{words}";
    }

    private static string Sha256Hex(string input)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
