namespace LojraLogjike.Api.Games.Zip;

public class ZipPuzzle
{
    public int Rows { get; set; }
    public int Cols { get; set; }
    public Dictionary<int, int> Numbers { get; set; } = new();
    public int[][] Walls { get; set; } = [];
    public int[] SolutionPath { get; set; } = [];
    public int DayIndex { get; set; }
    public string DayName { get; set; } = string.Empty;
}
