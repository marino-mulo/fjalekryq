namespace LojraLogjike.Api.Games.Tango;

/// <summary>
/// Backtracking solver for Tango puzzles.
/// Validates puzzle uniqueness by counting solutions (stops at 2).
/// </summary>
public static class TangoSolver
{
    private const int Size = 6;
    private const int Empty = -1;
    private const int Sun = 0;
    private const int Moon = 1;

    /// <summary>
    /// Returns true if the puzzle (prefilled + constraints) has exactly one valid solution.
    /// </summary>
    public static bool HasUniqueSolution(int[][] prefilled, TangoConstraint[] constraints)
    {
        return CountSolutions(prefilled, constraints, 2) == 1;
    }

    /// <summary>
    /// Counts solutions up to maxCount. Stops early once maxCount is reached.
    /// </summary>
    public static int CountSolutions(int[][] prefilled, TangoConstraint[] constraints, int maxCount = 2)
    {
        var board = new int[Size][];
        for (int r = 0; r < Size; r++)
            board[r] = (int[])prefilled[r].Clone();

        int count = 0;
        Solve(board, constraints, 0, ref count, maxCount);
        return count;
    }

    /// <summary>
    /// Finds one valid solution for the given prefilled board + constraints.
    /// Returns null if no solution exists.
    /// </summary>
    public static int[][]? FindSolution(int[][] prefilled, TangoConstraint[] constraints)
    {
        var board = new int[Size][];
        for (int r = 0; r < Size; r++)
            board[r] = (int[])prefilled[r].Clone();

        if (SolveOne(board, constraints, 0))
            return board;
        return null;
    }

    private static void Solve(int[][] board, TangoConstraint[] constraints, int pos, ref int count, int maxCount)
    {
        if (count >= maxCount) return;

        if (pos == Size * Size)
        {
            count++;
            return;
        }

        int row = pos / Size;
        int col = pos % Size;

        if (board[row][col] != Empty)
        {
            Solve(board, constraints, pos + 1, ref count, maxCount);
            return;
        }

        for (int val = Sun; val <= Moon; val++)
        {
            board[row][col] = val;
            if (IsValidPartial(board, constraints, row, col))
            {
                Solve(board, constraints, pos + 1, ref count, maxCount);
                if (count >= maxCount)
                {
                    board[row][col] = Empty;
                    return;
                }
            }
            board[row][col] = Empty;
        }
    }

    private static bool SolveOne(int[][] board, TangoConstraint[] constraints, int pos)
    {
        if (pos == Size * Size) return true;

        int row = pos / Size;
        int col = pos % Size;

        if (board[row][col] != Empty)
            return SolveOne(board, constraints, pos + 1);

        for (int val = Sun; val <= Moon; val++)
        {
            board[row][col] = val;
            if (IsValidPartial(board, constraints, row, col))
            {
                if (SolveOne(board, constraints, pos + 1))
                    return true;
            }
            board[row][col] = Empty;
        }
        return false;
    }

    /// <summary>
    /// Checks if placing the value at (row, col) doesn't violate any rules so far.
    /// - Row/column sun/moon count ≤ 3
    /// - No 3 consecutive identical symbols (horizontal or vertical)
    /// - All filled constraint pairs are satisfied
    /// </summary>
    private static bool IsValidPartial(int[][] board, TangoConstraint[] constraints, int row, int col)
    {
        int val = board[row][col];

        // Row count check
        int rowSun = 0, rowMoon = 0;
        for (int c = 0; c < Size; c++)
        {
            if (board[row][c] == Sun) rowSun++;
            else if (board[row][c] == Moon) rowMoon++;
        }
        if (rowSun > 3 || rowMoon > 3) return false;

        // Column count check
        int colSun = 0, colMoon = 0;
        for (int r = 0; r < Size; r++)
        {
            if (board[r][col] == Sun) colSun++;
            else if (board[r][col] == Moon) colMoon++;
        }
        if (colSun > 3 || colMoon > 3) return false;

        // Horizontal triple checks (all three patterns around current cell)
        if (col >= 2 && board[row][col - 1] == val && board[row][col - 2] == val)
            return false;
        if (col >= 1 && col < Size - 1 && board[row][col - 1] == val && board[row][col + 1] == val)
            return false;
        if (col < Size - 2 && board[row][col + 1] == val && board[row][col + 2] == val)
            return false;

        // Vertical triple checks (all three patterns around current cell)
        if (row >= 2 && board[row - 1][col] == val && board[row - 2][col] == val)
            return false;
        if (row >= 1 && row < Size - 1 && board[row - 1][col] == val && board[row + 1][col] == val)
            return false;
        if (row < Size - 2 && board[row + 1][col] == val && board[row + 2][col] == val)
            return false;

        // Constraint checks (only when both cells are filled)
        foreach (var ct in constraints)
        {
            int v1 = board[ct.R1][ct.C1];
            int v2 = board[ct.R2][ct.C2];
            if (v1 == Empty || v2 == Empty) continue;
            if (ct.Type == "same" && v1 != v2) return false;
            if (ct.Type == "diff" && v1 == v2) return false;
        }

        return true;
    }
}
