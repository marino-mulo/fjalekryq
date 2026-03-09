namespace LojraLogjike.Api.Games.Queens;

/// <summary>
/// Backtracking solver for Queens puzzles.
/// Constraints: one queen per row, one per column, one per zone, no adjacent queens (including diagonals).
/// </summary>
public static class QueensSolver
{
    /// <summary>
    /// Returns true if the zone layout has exactly one valid queen placement.
    /// </summary>
    public static bool HasUniqueSolution(int[][] zones, int size)
    {
        return CountSolutions(zones, size, 2) == 1;
    }

    /// <summary>
    /// Counts solutions up to maxCount. Stops early once maxCount is reached.
    /// </summary>
    public static int CountSolutions(int[][] zones, int size, int maxCount = 2)
    {
        var colUsed = new bool[size];
        var zoneUsed = new bool[size];
        var placement = new int[size];
        for (int i = 0; i < size; i++) placement[i] = -1;

        int count = 0;
        Backtrack(zones, size, 0, placement, colUsed, zoneUsed, ref count, maxCount);
        return count;
    }

    /// <summary>
    /// Finds the unique solution for the given zones. Returns null if none exists.
    /// </summary>
    public static int[]? FindSolution(int[][] zones, int size)
    {
        var colUsed = new bool[size];
        var zoneUsed = new bool[size];
        var placement = new int[size];
        for (int i = 0; i < size; i++) placement[i] = -1;

        if (SolveOne(zones, size, 0, placement, colUsed, zoneUsed))
            return placement;
        return null;
    }

    private static void Backtrack(int[][] zones, int size, int row, int[] placement,
        bool[] colUsed, bool[] zoneUsed, ref int count, int maxCount)
    {
        if (count >= maxCount) return;

        if (row == size)
        {
            count++;
            return;
        }

        for (int col = 0; col < size; col++)
        {
            if (colUsed[col]) continue;
            int zone = zones[row][col];
            if (zoneUsed[zone]) continue;

            // No adjacent touching with previous row's queen (including diagonals)
            if (row > 0)
            {
                int prevCol = placement[row - 1];
                if (Math.Abs(col - prevCol) <= 1) continue;
            }

            placement[row] = col;
            colUsed[col] = true;
            zoneUsed[zone] = true;

            Backtrack(zones, size, row + 1, placement, colUsed, zoneUsed, ref count, maxCount);

            colUsed[col] = false;
            zoneUsed[zone] = false;
            placement[row] = -1;

            if (count >= maxCount) return;
        }
    }

    private static bool SolveOne(int[][] zones, int size, int row, int[] placement,
        bool[] colUsed, bool[] zoneUsed)
    {
        if (row == size) return true;

        for (int col = 0; col < size; col++)
        {
            if (colUsed[col]) continue;
            int zone = zones[row][col];
            if (zoneUsed[zone]) continue;

            if (row > 0)
            {
                int prevCol = placement[row - 1];
                if (Math.Abs(col - prevCol) <= 1) continue;
            }

            placement[row] = col;
            colUsed[col] = true;
            zoneUsed[zone] = true;

            if (SolveOne(zones, size, row + 1, placement, colUsed, zoneUsed))
                return true;

            colUsed[col] = false;
            zoneUsed[zone] = false;
            placement[row] = -1;
        }
        return false;
    }
}
