using Fjalekryq.Api.Games.Wordle7;
using Microsoft.AspNetCore.Mvc;

namespace Fjalekryq.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PuzzlesController : ControllerBase
{
    [HttpGet("wordle7/random")]
    public IActionResult GetRandomWordle7([FromQuery] string? excludeWords = null, [FromQuery] string? difficulty = null)
    {
        // Parse comma-separated list of words to exclude (from previous puzzle)
        var excluded = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (!string.IsNullOrEmpty(excludeWords))
        {
            foreach (var w in excludeWords.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                excluded.Add(w);
            }
        }

        var seed = Environment.TickCount ^ Guid.NewGuid().GetHashCode();
        var normalizedDifficulty = difficulty?.ToLowerInvariant() switch
        {
            "easy" or "medium" or "hard" or "expert" => difficulty.ToLowerInvariant(),
            _ => "medium"
        };
        var puzzle = Wordle7Generator.GenerateRandom(seed, excluded, normalizedDifficulty);
        var hash = Wordle7Generator.ComputePuzzleHash(puzzle.Solution);

        // Swap limit is based on FILLED CELLS (unique non-X cells in the grid).
        // Theoretical minimum swaps to solve a random shuffle of L cells ≈ L × 0.63
        // (permutation-cycle theory: expected min = L - H(L) ≈ L × 0.632).
        // We use 0.65 (just above theoretical min) so a near-optimal player can
        // just barely finish, then add a small per-difficulty buffer so average
        // players are gently pushed toward using the Solve-Word hint.
        //
        // Easy:   ceil(filled × 0.65) + 10  ← most forgiving
        // Easy:   ceil(filled × 0.65) + 5   ← tightest (simple grids, less slack)
        // Medium: ceil(filled × 0.65) + 7
        // Hard:   ceil(filled × 0.65) + 10
        // Expert: ceil(filled × 0.65) + 12  ← most forgiving (complex grids)
        var filledCells = puzzle.Solution.Sum(row => row.Count(c => c != "X"));
        var swapLimit = normalizedDifficulty switch
        {
            "easy"   => (int)Math.Ceiling(filledCells * 0.65) + 5,
            "medium" => (int)Math.Ceiling(filledCells * 0.65) + 7,
            "hard"   => (int)Math.Ceiling(filledCells * 0.65) + 10,
            "expert" => (int)Math.Ceiling(filledCells * 0.65) + 12,
            _        => (int)Math.Ceiling(filledCells * 0.65) + 7,
        };

        return Ok(new { puzzle.GridSize, puzzle.Solution, puzzle.Words, Hash = hash, SwapLimit = swapLimit });
    }

    /// <summary>
    /// Returns a pre-generated puzzle for the given level (1-10).
    /// The puzzle is generated once at server startup and served instantly from memory.
    /// </summary>
    [HttpGet("wordle7/level/{level:int}")]
    public IActionResult GetWordle7Level(int level, [FromServices] LevelPuzzleStore store)
    {
        if (level < 1 || level > 10)
            return BadRequest(new { error = "Level must be between 1 and 10." });

        var entry = store.Get(level);
        if (entry is null)
            return StatusCode(503, new { error = "Puzzle not ready yet. Please retry." });

        return Ok(new
        {
            entry.Puzzle.GridSize,
            entry.Puzzle.Solution,
            entry.Puzzle.Words,
            Hash      = entry.Hash,
            SwapLimit = entry.SwapLimit,
        });
    }
}
