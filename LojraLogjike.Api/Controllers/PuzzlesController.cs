using LojraLogjike.Api.Games.Snake;
using LojraLogjike.Api.Games.Zip;
using LojraLogjike.Api.Games.Queens;
using LojraLogjike.Api.Games.Stars;
using LojraLogjike.Api.Games.Tango;
using LojraLogjike.Api.Games.Wordle7;
using Microsoft.AspNetCore.Mvc;

namespace LojraLogjike.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PuzzlesController : ControllerBase
{
    [HttpGet("zip/today")]
    public IActionResult GetTodayZip()
    {
        var puzzle = ZipPuzzleData.GetTodayPuzzle();
        return Ok(puzzle);
    }

    [HttpGet("zip/{dayIndex:int}")]
    public IActionResult GetZipByDay(int dayIndex)
    {
        var puzzle = ZipPuzzleData.GetPuzzleByDay(dayIndex);
        return Ok(puzzle);
    }

    [HttpGet("queens/today")]
    public IActionResult GetTodayQueens()
    {
        var puzzle = QueensPuzzleData.GetTodayPuzzle();
        return Ok(puzzle);
    }

    [HttpGet("queens/{dayIndex:int}")]
    public IActionResult GetQueensByDay(int dayIndex)
    {
        var puzzle = QueensPuzzleData.GetPuzzleByDay(dayIndex);
        return Ok(puzzle);
    }

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

    [HttpGet("tango/today")]
    public IActionResult GetTodayTango()
    {
        var puzzle = TangoPuzzleData.GetTodayPuzzle();
        return Ok(puzzle);
    }

    [HttpGet("tango/{dayIndex:int}")]
    public IActionResult GetTangoByDay(int dayIndex)
    {
        var puzzle = TangoPuzzleData.GetPuzzleByDay(dayIndex);
        return Ok(puzzle);
    }

    [HttpGet("stars/today")]
    public IActionResult GetTodayStars()
    {
        var puzzle = StarsPuzzleData.GetTodayPuzzle();
        return Ok(puzzle);
    }

    [HttpGet("stars/{dayIndex:int}")]
    public IActionResult GetStarsByDay(int dayIndex)
    {
        var puzzle = StarsPuzzleData.GetPuzzleByDay(dayIndex);
        return Ok(puzzle);
    }

    [HttpGet("snake/today")]
    public IActionResult GetTodaySnake()
    {
        var puzzle = SnakePuzzleData.GetTodayPuzzle();
        return Ok(puzzle);
    }

    [HttpGet("snake/{dayIndex:int}")]
    public IActionResult GetSnakeByDay(int dayIndex)
    {
        var puzzle = SnakePuzzleData.GetPuzzleByDay(dayIndex);
        return Ok(puzzle);
    }
}
