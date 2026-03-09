namespace LojraLogjike.Api.Games.Snake;

/// <summary>
/// Backtracking solver for Snake puzzles with node-count limit.
/// Supports "given" cells (pre-revealed positions with step numbers) for stronger pruning.
/// Builds a path from head to tail checking row/col clues, ortho-touch constraints, and givens.
/// Ortho-touch rule: no two non-consecutive snake cells can be orthogonally adjacent.
/// </summary>
public static class SnakeSolver
{
    private static readonly int[][] Dirs = [[0, 1], [1, 0], [0, -1], [-1, 0]];
    private const int MaxNodes = 2_000_000;

    /// <summary>
    /// Count solutions up to maxCount. Returns -1 if node limit exceeded (indeterminate).
    /// givens is an array of [row, col, stepNumber] triples for pre-revealed cells.
    /// </summary>
    public static int CountSolutions(int[] rowClues, int[] colClues,
        int headR, int headC, int tailR, int tailC, int size, int snakeLength,
        int[][] givens, int maxCount)
    {
        var grid = new int[size, size];
        var rowUsed = new int[size];
        var colUsed = new int[size];

        // Build given lookups: stepPos[step] = forced position, posStep[r,c] = reserved step
        var stepPos = new (int r, int c)[snakeLength + 1];
        for (int i = 0; i <= snakeLength; i++) stepPos[i] = (-1, -1);
        var posStep = new int[size, size]; // 0 = not reserved

        if (givens != null)
        {
            foreach (var g in givens)
            {
                stepPos[g[2]] = (g[0], g[1]);
                posStep[g[0], g[1]] = g[2];
            }
        }

        // Precompute: for each step s, what is the next forced (given) step >= s?
        var nextGivenStep = new int[snakeLength + 2];
        int nxt = snakeLength + 1;
        for (int s = snakeLength; s >= 0; s--)
        {
            if (stepPos[s].r >= 0) nxt = s;
            nextGivenStep[s] = nxt;
        }

        grid[headR, headC] = 1;
        rowUsed[headR] = 1;
        colUsed[headC] = 1;

        int count = 0;
        long nodes = 0;
        Solve(grid, rowUsed, colUsed, rowClues, colClues,
            headR, headC, tailR, tailC, size, snakeLength, 1,
            stepPos, posStep, nextGivenStep, ref count, maxCount, ref nodes);

        return nodes >= MaxNodes ? -1 : count;
    }

    private static void Solve(int[,] grid, int[] rowUsed, int[] colUsed,
        int[] rowClues, int[] colClues,
        int curR, int curC, int tailR, int tailC, int size, int snakeLength,
        int step, (int r, int c)[] stepPos, int[,] posStep, int[] nextGivenStep,
        ref int count, int maxCount, ref long nodes)
    {
        if (count >= maxCount || nodes >= MaxNodes) return;
        nodes++;

        if (step == snakeLength)
        {
            if (curR == tailR && curC == tailC && AllCluesMatch(rowUsed, colUsed, rowClues, colClues, size))
                count++;
            return;
        }

        int ns = step + 1; // next step to place
        int remaining = snakeLength - ns; // steps remaining AFTER placing ns

        // If next step has a forced position (it's a given)
        if (stepPos[ns].r >= 0)
        {
            int nr = stepPos[ns].r, nc = stepPos[ns].c;

            // Must be adjacent to current position
            if (Math.Abs(nr - curR) + Math.Abs(nc - curC) != 1) return;
            if (grid[nr, nc] != 0) return;
            if (rowUsed[nr] >= rowClues[nr]) return;
            if (colUsed[nc] >= colClues[nc]) return;
            if (remaining == 0 && (nr != tailR || nc != tailC)) return;
            if (remaining > 0 && nr == tailR && nc == tailC) return;

            // Ortho-touch: no non-consecutive orthogonal adjacency
            if (OrthoTouch(grid, nr, nc, curR, curC, size)) return;

            // Manhattan distance pruning to tail
            if (remaining > 0 && Math.Abs(nr - tailR) + Math.Abs(nc - tailC) > remaining) return;

            grid[nr, nc] = ns;
            rowUsed[nr]++;
            colUsed[nc]++;
            Solve(grid, rowUsed, colUsed, rowClues, colClues,
                nr, nc, tailR, tailC, size, snakeLength, ns,
                stepPos, posStep, nextGivenStep, ref count, maxCount, ref nodes);
            grid[nr, nc] = 0;
            rowUsed[nr]--;
            colUsed[nc]--;
            return;
        }

        // Normal: try all 4 directions
        for (int d = 0; d < 4; d++)
        {
            if (count >= maxCount || nodes >= MaxNodes) return;

            int nr = curR + Dirs[d][0];
            int nc = curC + Dirs[d][1];

            if ((uint)nr >= (uint)size || (uint)nc >= (uint)size) continue;
            if (grid[nr, nc] != 0) continue;
            if (rowUsed[nr] >= rowClues[nr]) continue;
            if (colUsed[nc] >= colClues[nc]) continue;

            // This position is reserved for a different step
            if (posStep[nr, nc] != 0 && posStep[nr, nc] != ns) continue;

            if (remaining == 0 && (nr != tailR || nc != tailC)) continue;
            if (remaining > 0 && nr == tailR && nc == tailC) continue;

            // Ortho-touch: no non-consecutive orthogonal adjacency
            if (OrthoTouch(grid, nr, nc, curR, curC, size)) continue;

            // Pruning: Manhattan distance to tail
            if (remaining > 0 && Math.Abs(nr - tailR) + Math.Abs(nc - tailC) > remaining) continue;

            // Pruning: Manhattan distance to next upcoming given
            int ngs = nextGivenStep[ns];
            if (ngs <= snakeLength)
            {
                var gp = stepPos[ngs];
                if (Math.Abs(nr - gp.r) + Math.Abs(nc - gp.c) > ngs - ns) continue;
            }

            grid[nr, nc] = ns;
            rowUsed[nr]++;
            colUsed[nc]++;
            Solve(grid, rowUsed, colUsed, rowClues, colClues,
                nr, nc, tailR, tailC, size, snakeLength, ns,
                stepPos, posStep, nextGivenStep, ref count, maxCount, ref nodes);
            grid[nr, nc] = 0;
            rowUsed[nr]--;
            colUsed[nc]--;
        }
    }

    /// <summary>
    /// Check if placing a cell at (nr, nc) would create an orthogonal self-touch:
    /// an orthogonally adjacent cell that is occupied by a non-consecutive snake cell.
    /// The only allowed occupied orthogonal neighbor is the previous cell (prevR, prevC).
    /// </summary>
    private static bool OrthoTouch(int[,] grid, int nr, int nc, int prevR, int prevC, int size)
    {
        if (nr > 0 && grid[nr - 1, nc] != 0 && !(nr - 1 == prevR && nc == prevC)) return true;
        if (nr < size - 1 && grid[nr + 1, nc] != 0 && !(nr + 1 == prevR && nc == prevC)) return true;
        if (nc > 0 && grid[nr, nc - 1] != 0 && !(nr == prevR && nc - 1 == prevC)) return true;
        if (nc < size - 1 && grid[nr, nc + 1] != 0 && !(nr == prevR && nc + 1 == prevC)) return true;
        return false;
    }

    private static bool AllCluesMatch(int[] rowUsed, int[] colUsed, int[] rowClues, int[] colClues, int size)
    {
        for (int i = 0; i < size; i++)
            if (rowUsed[i] != rowClues[i] || colUsed[i] != colClues[i]) return false;
        return true;
    }
}
