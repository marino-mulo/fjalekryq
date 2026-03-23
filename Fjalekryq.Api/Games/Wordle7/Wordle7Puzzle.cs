namespace Fjalekryq.Api.Games.Wordle7;

public class Wordle7Puzzle
{
    public int GridSize { get; set; } = 7;
    public string[][] Solution { get; set; } = [];
    public WordEntry[] Words { get; set; } = [];
}

public class WordEntry
{
    public string Word { get; set; } = string.Empty;
    public int Row { get; set; }
    public int Col { get; set; }
    public string Direction { get; set; } = "horizontal";
}
