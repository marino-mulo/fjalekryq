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

        // Swap limit = sum of all word lengths * multiplier (+ extra moves per tier)
        // Easy:   ceil(totalLetters * 1.6)
        // Medium: ceil(totalLetters * 1.5) + 5
        // Hard:   ceil(totalLetters * 1.4) + 10
        // Expert: ceil(totalLetters * 1.2) + 15
        var totalWordLetters = puzzle.Words.Sum(w => w.Word.Length);
        var swapLimit = normalizedDifficulty switch
        {
            "easy"   => (int)Math.Ceiling(totalWordLetters * 1.6),
            "medium" => (int)Math.Ceiling(totalWordLetters * 1.5) + 5,
            "hard"   => (int)Math.Ceiling(totalWordLetters * 1.4) + 10,
            "expert" => (int)Math.Ceiling(totalWordLetters * 1.2) + 15,
            _        => (int)Math.Ceiling(totalWordLetters * 1.5) + 5,
        };

        return Ok(new { puzzle.GridSize, puzzle.Solution, puzzle.Words, Hash = hash, SwapLimit = swapLimit });
    }
}
