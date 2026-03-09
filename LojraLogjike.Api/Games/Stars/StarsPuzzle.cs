namespace LojraLogjike.Api.Games.Stars;

public class StarsPuzzle
{
    public int Size { get; set; }
    public int[][] Zones { get; set; } = [];
    public int[][] Solution { get; set; } = []; // Solution[row] = [col1, col2] sorted
    public int DayIndex { get; set; }
    public string DayName { get; set; } = string.Empty;
}
