namespace LojraLogjike.Api.Games.Stars;

/// <summary>
/// Backtracking solver for Stars puzzles with forward-checking pruning.
/// Constraints: two stars per row, two per column, two per zone, no adjacent stars (including diagonals).
/// </summary>
public static class StarsSolver
{
    public static bool HasUniqueSolution(int[][] zones, int size)
    {
        return CountSolutions(zones, size, 2) == 1;
    }

    public static int CountSolutions(int[][] zones, int size, int maxCount = 2)
    {
        var colCount = new int[size];
        var zoneCount = new int[size];
        var placement = new int[size][];
        for (int i = 0; i < size; i++) placement[i] = [-1, -1];

        int count = 0;
        Backtrack(zones, size, 0, placement, colCount, zoneCount, ref count, maxCount);
        return count;
    }

    public static int[][]? FindSolution(int[][] zones, int size)
    {
        var colCount = new int[size];
        var zoneCount = new int[size];
        var placement = new int[size][];
        for (int i = 0; i < size; i++) placement[i] = [-1, -1];

        if (SolveOne(zones, size, 0, placement, colCount, zoneCount))
            return placement.Select(p => (int[])p.Clone()).ToArray();
        return null;
    }

    private static void Backtrack(int[][] zones, int size, int row, int[][] placement,
        int[] colCount, int[] zoneCount, ref int count, int maxCount)
    {
        if (count >= maxCount) return;
        if (row == size) { count++; return; }

        bool hasPrev = row > 0;
        int[] prev = hasPrev ? placement[row - 1] : null!;

        for (int c1 = 0; c1 < size - 2; c1++)
        {
            if (colCount[c1] >= 2) continue;
            if (hasPrev && IsAdj(c1, prev)) continue;
            int z1 = zones[row][c1];
            if (zoneCount[z1] >= 2) continue;

            for (int c2 = c1 + 2; c2 < size; c2++)
            {
                if (count >= maxCount) return;
                if (colCount[c2] >= 2) continue;
                if (hasPrev && IsAdj(c2, prev)) continue;
                int z2 = zones[row][c2];
                if (zoneCount[z2] >= 2) continue;
                if (z1 == z2 && zoneCount[z1] >= 1) continue; // same zone, already has 1 star

                // Place
                placement[row][0] = c1; placement[row][1] = c2;
                colCount[c1]++; colCount[c2]++;
                zoneCount[z1]++; if (z1 != z2) zoneCount[z2]++;

                if (ForwardCheck(zones, size, row + 1, placement[row], colCount, zoneCount))
                    Backtrack(zones, size, row + 1, placement, colCount, zoneCount, ref count, maxCount);

                // Undo
                colCount[c1]--; colCount[c2]--;
                zoneCount[z1]--; if (z1 != z2) zoneCount[z2]--;
                placement[row][0] = -1; placement[row][1] = -1;

                if (count >= maxCount) return;
            }
        }
    }

    private static bool SolveOne(int[][] zones, int size, int row, int[][] placement,
        int[] colCount, int[] zoneCount)
    {
        if (row == size) return true;

        bool hasPrev = row > 0;
        int[] prev = hasPrev ? placement[row - 1] : null!;

        for (int c1 = 0; c1 < size - 2; c1++)
        {
            if (colCount[c1] >= 2) continue;
            if (hasPrev && IsAdj(c1, prev)) continue;
            int z1 = zones[row][c1];
            if (zoneCount[z1] >= 2) continue;

            for (int c2 = c1 + 2; c2 < size; c2++)
            {
                if (colCount[c2] >= 2) continue;
                if (hasPrev && IsAdj(c2, prev)) continue;
                int z2 = zones[row][c2];
                if (zoneCount[z2] >= 2) continue;
                if (z1 == z2 && zoneCount[z1] >= 1) continue;

                placement[row][0] = c1; placement[row][1] = c2;
                colCount[c1]++; colCount[c2]++;
                zoneCount[z1]++; if (z1 != z2) zoneCount[z2]++;

                bool ok = ForwardCheck(zones, size, row + 1, placement[row], colCount, zoneCount)
                          && SolveOne(zones, size, row + 1, placement, colCount, zoneCount);

                colCount[c1]--; colCount[c2]--;
                zoneCount[z1]--; if (z1 != z2) zoneCount[z2]--;
                placement[row][0] = -1; placement[row][1] = -1;

                if (ok) return true;
            }
        }
        return false;
    }

    /// <summary>
    /// Forward check for the immediately next row.
    /// Also checks zone feasibility for all zones.
    /// </summary>
    private static bool ForwardCheck(int[][] zones, int size, int nextRow,
        int[] justPlaced, int[] colCount, int[] zoneCount)
    {
        // (a) Next row must have at least one valid pair
        // (we only check the next row since we can't predict adjacency beyond that)
        if (nextRow < size)
        {
            bool found = false;
            for (int c1 = 0; c1 < size - 2 && !found; c1++)
            {
                if (colCount[c1] >= 2) continue;
                if (IsAdj(c1, justPlaced)) continue;
                int z1 = zones[nextRow][c1];
                if (zoneCount[z1] >= 2) continue;

                for (int c2 = c1 + 2; c2 < size && !found; c2++)
                {
                    if (colCount[c2] >= 2) continue;
                    if (IsAdj(c2, justPlaced)) continue;
                    int z2 = zones[nextRow][c2];
                    if (zoneCount[z2] >= 2) continue;
                    if (z1 == z2 && zoneCount[z1] >= 1) continue;
                    found = true;
                }
            }
            if (!found) return false;
        }

        // (b) Every unsatisfied zone must have ≥ (2 - zoneCount[z]) available cells
        //     in rows nextRow..size-1 with available columns
        for (int z = 0; z < size; z++)
        {
            int needed = 2 - zoneCount[z];
            if (needed <= 0) continue;

            int available = 0;
            for (int r = nextRow; r < size && available < needed; r++)
                for (int c = 0; c < size && available < needed; c++)
                    if (zones[r][c] == z && colCount[c] < 2) available++;

            if (available < needed) return false;
        }

        // (c) Each remaining row must have at least 2 available columns (fast check)
        //     (not checking zone constraints for simplicity — already covered by (b))
        int colsAvailable = 0;
        for (int c = 0; c < size; c++)
            if (colCount[c] < 2) colsAvailable++;
        // Remaining rows need 2 stars each; total stars needed = 2*(size-nextRow)
        // Total available column slots = sum of (2-colCount[c]) over all c
        int totalSlots = 0;
        for (int c = 0; c < size; c++)
            totalSlots += 2 - colCount[c];
        if (totalSlots < 2 * (size - nextRow)) return false;

        return true;
    }

    private static bool IsAdj(int col, int[] stars)
    {
        return Math.Abs(col - stars[0]) <= 1 || Math.Abs(col - stars[1]) <= 1;
    }
}
