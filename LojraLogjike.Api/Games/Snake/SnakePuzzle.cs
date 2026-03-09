namespace LojraLogjike.Api.Games.Snake;

public class SnakePuzzle
{
    public int Size { get; set; }
    public int[] RowClues { get; set; } = [];
    public int[] ColClues { get; set; } = [];
    public int HeadRow { get; set; }
    public int HeadCol { get; set; }
    public int TailRow { get; set; }
    public int TailCol { get; set; }
    public int SnakeLength { get; set; }
    public int[][] Givens { get; set; } = []; // Array of [row, col, stepNumber] for revealed cells
    public int[][] Solution { get; set; } = []; // 0=empty, 1..N=path order (1=head, N=tail)
    public int DayIndex { get; set; }
    public string DayName { get; set; } = string.Empty;
}
