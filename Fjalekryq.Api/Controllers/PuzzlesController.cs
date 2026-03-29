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
        var puzzle = Wordle7Generator.GenerateRandom(seed, excluded);
        var hash = Wordle7Generator.ComputePuzzleHash(puzzle.Solution);

        // Swap limit multiplier based on difficulty
        var letterCount = puzzle.Solution.Sum(row => row.Count(c => c != "X"));
        double multiplier = difficulty switch
        {
            "easy"    => 2.0,
            "medium"  => 1.5,
            "hard"    => 1.1,
            "extreme" => 0.85,
            _         => 1.5,
        };
        var swapLimit = (int)Math.Ceiling(letterCount * multiplier);

        return Ok(new { puzzle.GridSize, puzzle.Solution, puzzle.Words, Hash = hash, SwapLimit = swapLimit });
    }
}
