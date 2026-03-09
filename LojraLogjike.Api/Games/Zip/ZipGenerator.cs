namespace LojraLogjike.Api.Games.Zip;

/// <summary>
/// Generates Zip puzzles with Hamiltonian paths.
/// Uses Warnsdorff's heuristic for fast path generation.
/// Places walls and checkpoints to constrain the puzzle.
/// </summary>
public static class ZipGenerator
{
    private static readonly (int rows, int cols)[] DaySizes =
        [(5, 5), (5, 5), (6, 6), (7, 7), (7, 7), (8, 8), (9, 9)];

    // Target checkpoint count per day (more checkpoints = easier)
    private static readonly int[] DayCheckpoints = [5, 6, 7, 7, 8, 8, 9];

    private static readonly int[] DR = [-1, 1, 0, 0];
    private static readonly int[] DC = [0, 0, -1, 1];

    /// <summary>
    /// Generate a Zip puzzle for a given seed and day.
    /// </summary>
    public static ZipPuzzle Generate(int seed, int dayIndex, string dayName)
    {
        var (rows, cols) = DaySizes[Math.Clamp(dayIndex, 0, 6)];
        int targetCp = DayCheckpoints[Math.Clamp(dayIndex, 0, 6)];

        for (int seedOffset = 0; seedOffset < 50; seedOffset++)
        {
            var rng = new Random(seed + seedOffset * 13579);

            for (int attempt = 0; attempt < 50; attempt++)
            {
                var result = TryGenerate(rows, cols, targetCp, rng);
                if (result != null)
                {
                    return new ZipPuzzle
                    {
                        Rows = rows,
                        Cols = cols,
                        Numbers = result.Value.numbers,
                        Walls = result.Value.walls,
                        SolutionPath = result.Value.path,
                        DayIndex = dayIndex,
                        DayName = dayName
                    };
                }
            }
        }

        throw new InvalidOperationException($"Failed to generate Zip puzzle for day {dayIndex}");
    }

    private static (int[] path, Dictionary<int, int> numbers, int[][] walls)? TryGenerate(
        int rows, int cols, int targetCheckpoints, Random rng)
    {
        int total = rows * cols;

        // Step 1: Generate a random Hamiltonian path using Warnsdorff's heuristic
        var path = WarnsdorffPath(rows, cols, rng);
        if (path == null) return null;

        // Step 2: Build path edge set
        var pathEdges = new HashSet<long>();
        for (int i = 0; i < path.Length - 1; i++)
        {
            int r1 = path[i] / cols, c1 = path[i] % cols;
            int r2 = path[i + 1] / cols, c2 = path[i + 1] % cols;
            pathEdges.Add(EdgeKey(r1, c1, r2, c2));
            pathEdges.Add(EdgeKey(r2, c2, r1, c1));
        }

        // Step 3: Collect non-path adjacent pairs as potential walls
        var potentialWalls = new List<int[]>();
        for (int r = 0; r < rows; r++)
        {
            for (int c = 0; c < cols; c++)
            {
                for (int d = 0; d < 4; d++)
                {
                    int nr = r + DR[d], nc = c + DC[d];
                    if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                    if (nr < r || (nr == r && nc < c)) continue;
                    if (!pathEdges.Contains(EdgeKey(r, c, nr, nc)))
                        potentialWalls.Add([r, c, nr, nc]);
                }
            }
        }

        Shuffle(potentialWalls, rng);
        int wallCount = Math.Min(potentialWalls.Count, rng.Next(2, Math.Min(6, potentialWalls.Count + 1)));
        var walls = potentialWalls.Take(wallCount).ToArray();

        // Step 4: Place checkpoints
        int start = path[0];
        int end = path[^1];
        var checkpointIndices = new List<int> { 0, path.Length - 1 };

        int remaining = targetCheckpoints - 2;
        if (remaining > 0)
        {
            int spacing = Math.Max(1, (path.Length - 2) / (remaining + 1));
            var added = new HashSet<int>();

            for (int k = 1; k <= remaining; k++)
            {
                int idx = k * spacing;
                int jittered = idx + rng.Next(-1, 2);
                jittered = Math.Clamp(jittered, 1, path.Length - 2);
                if (!added.Contains(jittered))
                {
                    added.Add(jittered);
                    checkpointIndices.Add(jittered);
                }
            }

            // Fill remaining from random positions
            if (added.Count < remaining)
            {
                var candidates = Enumerable.Range(1, path.Length - 2).ToList();
                Shuffle(candidates, rng);
                foreach (int idx in candidates)
                {
                    if (added.Count >= remaining) break;
                    if (!added.Contains(idx))
                    {
                        added.Add(idx);
                        checkpointIndices.Add(idx);
                    }
                }
            }
        }

        checkpointIndices.Sort();

        var numbers = new Dictionary<int, int>();
        for (int i = 0; i < checkpointIndices.Count; i++)
        {
            int cellIdx = path[checkpointIndices[i]];
            numbers[cellIdx] = i + 1;
        }

        return (path, numbers, walls);
    }

    /// <summary>
    /// Generate a Hamiltonian path using Warnsdorff's heuristic.
    /// Always visits the neighbor with the fewest onward moves first.
    /// Very fast — works for grids up to 100×100+.
    /// </summary>
    private static int[]? WarnsdorffPath(int rows, int cols, Random rng)
    {
        int total = rows * cols;

        // Try multiple random starts
        for (int trial = 0; trial < 20; trial++)
        {
            int startR = rng.Next(rows), startC = rng.Next(cols);
            var result = WarnsdorffFromStart(rows, cols, startR, startC, rng);
            if (result != null) return result;
        }
        return null;
    }

    private static int[]? WarnsdorffFromStart(int rows, int cols, int startR, int startC, Random rng)
    {
        int total = rows * cols;
        var visited = new bool[rows, cols];
        var path = new int[total];
        int idx = 0;

        int cr = startR, cc = startC;
        visited[cr, cc] = true;
        path[idx++] = cr * cols + cc;

        while (idx < total)
        {
            // Find all unvisited neighbors
            var neighbors = new List<(int r, int c, int degree)>();
            for (int d = 0; d < 4; d++)
            {
                int nr = cr + DR[d], nc = cc + DC[d];
                if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                if (visited[nr, nc]) continue;

                // Count onward moves (Warnsdorff's degree)
                int degree = 0;
                for (int d2 = 0; d2 < 4; d2++)
                {
                    int nnr = nr + DR[d2], nnc = nc + DC[d2];
                    if (nnr >= 0 && nnr < rows && nnc >= 0 && nnc < cols && !visited[nnr, nnc])
                        degree++;
                }
                neighbors.Add((nr, nc, degree));
            }

            if (neighbors.Count == 0) return null; // Stuck

            // Sort by degree (Warnsdorff: prefer fewest onward moves)
            // Break ties randomly
            neighbors.Sort((a, b) =>
            {
                int cmp = a.degree.CompareTo(b.degree);
                return cmp != 0 ? cmp : rng.Next(-1, 2);
            });

            var (nextR, nextC, _) = neighbors[0];
            visited[nextR, nextC] = true;
            path[idx++] = nextR * cols + nextC;
            cr = nextR;
            cc = nextC;
        }

        return path;
    }

    private static long EdgeKey(int r1, int c1, int r2, int c2)
    {
        return ((long)r1 << 24) | ((long)c1 << 16) | ((long)r2 << 8) | c2;
    }

    private static void Shuffle<T>(List<T> list, Random rng)
    {
        for (int i = list.Count - 1; i > 0; i--)
        {
            int j = rng.Next(i + 1);
            (list[i], list[j]) = (list[j], list[i]);
        }
    }
}
