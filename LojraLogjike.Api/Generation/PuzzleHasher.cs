using System.Security.Cryptography;
using System.Text;
using LojraLogjike.Api.Games.Snake;
using LojraLogjike.Api.Games.Zip;
using LojraLogjike.Api.Games.Queens;
using LojraLogjike.Api.Games.Stars;
using LojraLogjike.Api.Games.Tango;
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
            "snake" => GetSnakeFingerprint((SnakePuzzle)puzzle),
            "zip" => GetZipFingerprint((ZipPuzzle)puzzle),
            "queens" => GetQueensFingerprint((QueensPuzzle)puzzle),
            "stars" => GetStarsFingerprint((StarsPuzzle)puzzle),
            "tango" => GetTangoFingerprint((TangoPuzzle)puzzle),
            "wordle7" => GetWordle7Fingerprint((Wordle7Puzzle)puzzle),
            _ => throw new ArgumentException($"Unknown game: {gameName}")
        };

        return Sha256Hex(fingerprint);
    }

    // ── Fingerprint extractors (solution-only data) ──

    private static string GetSnakeFingerprint(SnakePuzzle p)
    {
        // Flatten 2D solution grid: "1,0,0;0,2,3;0,0,4"
        return string.Join(";", p.Solution.Select(row => string.Join(",", row)));
    }

    private static string GetZipFingerprint(ZipPuzzle p)
    {
        // Solution path as comma-separated values
        return $"{p.Rows}x{p.Cols}:" + string.Join(",", p.SolutionPath);
    }

    private static string GetQueensFingerprint(QueensPuzzle p)
    {
        // Queen columns per row + zones for full uniqueness
        var sol = string.Join(",", p.Solution);
        var zones = string.Join(";", p.Zones.Select(row => string.Join(",", row)));
        return $"{p.Size}:{sol}|{zones}";
    }

    private static string GetStarsFingerprint(StarsPuzzle p)
    {
        // Star positions + zones
        var sol = string.Join(";", p.Solution.Select(row => string.Join(",", row)));
        var zones = string.Join(";", p.Zones.Select(row => string.Join(",", row)));
        return $"{p.Size}:{sol}|{zones}";
    }

    private static string GetTangoFingerprint(TangoPuzzle p)
    {
        // Full solution grid + prefilled + constraints
        var sol = string.Join(";", p.Solution.Select(row => string.Join(",", row)));
        var pre = string.Join(";", p.Prefilled.Select(row => string.Join(",", row)));
        var con = string.Join(";", p.Constraints.Select(c => $"{c.R1},{c.C1},{c.R2},{c.C2},{c.Type}"));
        return $"{sol}|{pre}|{con}";
    }

    private static string GetWordle7Fingerprint(Wordle7Puzzle p)
    {
        // Letter grid + words
        var sol = string.Join(";", p.Solution.Select(row => string.Join(",", row)));
        var words = string.Join(";", p.Words.Select(w => $"{w.Word},{w.Row},{w.Col},{w.Direction}"));
        return $"{p.GridSize}:{sol}|{words}";
    }

    // ── Hashing ──

    private static string Sha256Hex(string input)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
