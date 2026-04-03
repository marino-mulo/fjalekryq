using Fjalekryq.Api.Games.Wordle7;
using Microsoft.AspNetCore.Mvc;

namespace Fjalekryq.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PuzzlesController : ControllerBase
{
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
