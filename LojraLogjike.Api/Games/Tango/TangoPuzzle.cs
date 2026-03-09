namespace LojraLogjike.Api.Games.Tango;

public class TangoPuzzle
{
    public int[][] Solution { get; set; } = [];
    public int[][] Prefilled { get; set; } = [];
    public TangoConstraint[] Constraints { get; set; } = [];
    public int DayIndex { get; set; }
    public string DayName { get; set; } = string.Empty;
}

public class TangoConstraint
{
    public int R1 { get; set; }
    public int C1 { get; set; }
    public int R2 { get; set; }
    public int C2 { get; set; }
    /// <summary>"same" = both cells must be equal, "diff" = both cells must differ</summary>
    public string Type { get; set; } = "same";
}
