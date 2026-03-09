namespace LojraLogjike.Api.Games.Zip;

/// <summary>
/// DFS Hamiltonian path solver for Zip puzzles.
/// Finds paths visiting all cells, respecting walls and checkpoint ordering.
/// </summary>
public static class ZipSolver
{
    /// <summary>
    /// Solve the Zip puzzle: find a Hamiltonian path from start to end
    /// visiting all cells, respecting walls and checkpoint order.
    /// </summary>
    public static int[]? Solve(int rows, int cols, int start, int end, int[][] walls,
        int[] checkpointCells)
    {
        int total = rows * cols;

        // Build wall set
        var wallSet = BuildWallSet(rows, cols, walls);

        // Build adjacency list
        var adj = BuildAdjacency(rows, cols, wallSet);

        // Checkpoint set for quick lookup
        var cpSet = new HashSet<int>(checkpointCells);

        var visited = new bool[total];
        var path = new List<int>(total) { start };
        visited[start] = true;
        int[] found = null!;
        int attempts = 0;

        void Dfs()
        {
            attempts++;
            if (attempts > 10_000_000 || found != null) return;

            if (path.Count == total)
            {
                if (path[^1] == end)
                {
                    // Verify checkpoints are in order
                    int cpIdx = 0;
                    foreach (int cell in path)
                    {
                        if (cpIdx < checkpointCells.Length && cell == checkpointCells[cpIdx])
                            cpIdx++;
                    }
                    if (cpIdx == checkpointCells.Length)
                        found = path.ToArray();
                }
                return;
            }

            int cur = path[^1];

            // Pruning: if one cell left, it must be end and adjacent
            if (path.Count == total - 1)
            {
                if (!adj[cur].Contains(end) || visited[end]) return;
            }

            foreach (int next in adj[cur])
            {
                if (visited[next]) continue;

                // Check checkpoint ordering
                if (cpSet.Contains(next))
                {
                    int cpPos = Array.IndexOf(checkpointCells, next);
                    int visitedCps = 0;
                    foreach (int cell in path)
                    {
                        if (cpSet.Contains(cell) && Array.IndexOf(checkpointCells, cell) == visitedCps)
                            visitedCps++;
                    }
                    if (cpPos != visitedCps) continue;
                }

                visited[next] = true;
                path.Add(next);
                Dfs();
                if (found != null) return;
                path.RemoveAt(path.Count - 1);
                visited[next] = false;
            }
        }

        Dfs();
        return found;
    }

    /// <summary>
    /// Count solutions up to maxCount. Used for uniqueness checking.
    /// </summary>
    public static int CountSolutions(int rows, int cols, int start, int end, int[][] walls,
        int[] checkpointCells, int maxCount = 2)
    {
        int total = rows * cols;
        var wallSet = BuildWallSet(rows, cols, walls);
        var adj = BuildAdjacency(rows, cols, wallSet);
        var cpSet = new HashSet<int>(checkpointCells);

        var visited = new bool[total];
        var path = new List<int>(total) { start };
        visited[start] = true;
        int count = 0;
        int attempts = 0;

        void Dfs()
        {
            attempts++;
            if (attempts > 10_000_000 || count >= maxCount) return;

            if (path.Count == total)
            {
                if (path[^1] == end)
                {
                    int cpIdx = 0;
                    foreach (int cell in path)
                    {
                        if (cpIdx < checkpointCells.Length && cell == checkpointCells[cpIdx])
                            cpIdx++;
                    }
                    if (cpIdx == checkpointCells.Length)
                        count++;
                }
                return;
            }

            int cur = path[^1];

            if (path.Count == total - 1)
            {
                if (!adj[cur].Contains(end) || visited[end]) return;
            }

            foreach (int next in adj[cur])
            {
                if (visited[next]) continue;
                if (count >= maxCount) return;

                if (cpSet.Contains(next))
                {
                    int cpPos = Array.IndexOf(checkpointCells, next);
                    int visitedCps = 0;
                    foreach (int cell in path)
                    {
                        if (cpSet.Contains(cell) && Array.IndexOf(checkpointCells, cell) == visitedCps)
                            visitedCps++;
                    }
                    if (cpPos != visitedCps) continue;
                }

                visited[next] = true;
                path.Add(next);
                Dfs();
                if (count >= maxCount) { path.RemoveAt(path.Count - 1); visited[next] = false; return; }
                path.RemoveAt(path.Count - 1);
                visited[next] = false;
            }
        }

        Dfs();
        return count;
    }

    public static bool HasUniqueSolution(int rows, int cols, int start, int end, int[][] walls,
        int[] checkpointCells)
    {
        return CountSolutions(rows, cols, start, end, walls, checkpointCells, 2) == 1;
    }

    private static HashSet<string> BuildWallSet(int rows, int cols, int[][] walls)
    {
        var wallSet = new HashSet<string>();
        foreach (var w in walls)
        {
            wallSet.Add($"{w[0]},{w[1]}>{w[2]},{w[3]}");
            wallSet.Add($"{w[2]},{w[3]}>{w[0]},{w[1]}");
        }
        return wallSet;
    }

    private static List<int>[] BuildAdjacency(int rows, int cols, HashSet<string> wallSet)
    {
        int total = rows * cols;
        var adj = new List<int>[total];
        for (int i = 0; i < total; i++) adj[i] = new List<int>();

        int[][] dirs = [[- 1, 0], [1, 0], [0, -1], [0, 1]];

        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < cols; c++)
            {
                int i = r * cols + c;
                foreach (var d in dirs)
                {
                    int nr = r + d[0], nc = c + d[1];
                    if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                    if (wallSet.Contains($"{r},{c}>{nr},{nc}")) continue;
                    adj[i].Add(nr * cols + nc);
                }
            }
        }
        return adj;
    }
}
