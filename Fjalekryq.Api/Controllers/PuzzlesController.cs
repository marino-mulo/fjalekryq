using Fjalekryq.Api.Games.Wordle7;
using Microsoft.AspNetCore.Mvc;

namespace Fjalekryq.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PuzzlesController : ControllerBase
{
    [HttpGet("wordle7/random")]
    public IActionResult GetRandomWordle7([FromQuery] string? excludeHash = null)
    {
        const int maxRetries = 10;
        for (int i = 0; i < maxRetries; i++)
        {
            var seed = Environment.TickCount ^ Guid.NewGuid().GetHashCode() ^ i;
            var puzzle = Wordle7Generator.GenerateRandom(seed);
            var hash = Wordle7Generator.ComputePuzzleHash(puzzle.Solution);

            if (excludeHash == null || hash != excludeHash)
            {
                return Ok(new { puzzle.GridSize, puzzle.Solution, puzzle.Words, Hash = hash });
            }
        }

        // Fallback: return whatever we get
        var fallbackSeed = Environment.TickCount ^ Guid.NewGuid().GetHashCode();
        var fallback = Wordle7Generator.GenerateRandom(fallbackSeed);
        var fallbackHash = Wordle7Generator.ComputePuzzleHash(fallback.Solution);
        return Ok(new { fallback.GridSize, fallback.Solution, fallback.Words, Hash = fallbackHash });
    }
}
