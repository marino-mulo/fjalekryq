namespace LojraLogjike.Api.Games.Queens;

public class QueensPuzzle
{
    public int Size { get; set; }
    public int[][] Zones { get; set; } = [];
    public int[] Solution { get; set; } = [];
    public int DayIndex { get; set; }
    public string DayName { get; set; } = string.Empty;
}
