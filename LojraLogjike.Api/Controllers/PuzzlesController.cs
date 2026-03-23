using LojraLogjike.Api.Games.Wordle7;
using Microsoft.AspNetCore.Mvc;

namespace LojraLogjike.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PuzzlesController : ControllerBase
{
    [HttpGet("wordle7/today")]
    public IActionResult GetTodayWordle7()
    {
        var puzzle = Wordle7PuzzleData.GetTodayPuzzle();
        return Ok(puzzle);
    }

    [HttpGet("wordle7/{dayIndex:int}")]
    public IActionResult GetWordle7ByDay(int dayIndex)
    {
        var puzzle = Wordle7PuzzleData.GetPuzzleByDay(dayIndex);
        return Ok(puzzle);
    }

    [HttpGet("wordle7/random")]
    public IActionResult GetRandomWordle7()
    {
        var seed = Environment.TickCount ^ Guid.NewGuid().GetHashCode();
        var puzzle = Wordle7Generator.GenerateRandom(seed);
        return Ok(puzzle);
    }
}
