using Fjalekryq.Api.Games.Wordle7;
using Microsoft.AspNetCore.Mvc;

namespace Fjalekryq.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PuzzlesController : ControllerBase
{
    [HttpGet("wordle7/random")]
    public IActionResult GetRandomWordle7([FromQuery] string? excludeWords = null)
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

        return Ok(new { puzzle.GridSize, puzzle.Solution, puzzle.Words, Hash = hash });
    }
}
