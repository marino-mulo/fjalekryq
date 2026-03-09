namespace LojraLogjike.Api.Games.Queens;

/// <summary>
/// Generates Queens puzzles with guaranteed unique solutions.
/// Algorithm: random queen placement → BFS zone expansion → verify uniqueness.
/// </summary>
public static class QueensGenerator
{
    private static readonly int[] DaySizes = [7, 8, 9, 9, 10, 10, 11];

    private static readonly int[][] Dirs = [[0, 1], [0, -1], [1, 0], [-1, 0]];

    /// <summary>
    /// Generate a Queens puzzle for a given seed and day.
    /// Tries multiple seed offsets if the initial seed doesn't produce a result.
    /// </summary>
    public static QueensPuzzle Generate(int seed, int dayIndex, string dayName)
    {
        int size = DaySizes[Math.Clamp(dayIndex, 0, 6)];

        // Try with multiple seed offsets to guarantee success
        for (int seedOffset = 0; seedOffset < 20; seedOffset++)
        {
            var rng = new Random(seed + seedOffset * 31337);

            int zonesPerPlacement = size <= 8 ? 3 : size <= 10 ? 10 : 20;
            int maxPlacements = size <= 8 ? 200 : size <= 10 ? 500 : 1000;

            for (int p = 0; p < maxPlacements; p++)
            {
                var solution = RandomQueenPlacement(size, rng);
                if (solution == null) continue;

                for (int z = 0; z < zonesPerPlacement; z++)
                {
                    var zones = GenerateZones(size, solution, rng);

                    if (!HasAllZones(zones, size)) continue;
                    if (!ZonesConnected(zones, size)) continue;

                    if (!QueensSolver.HasUniqueSolution(zones, size)) continue;

                    return new QueensPuzzle
                    {
                        Size = size,
                        Zones = zones,
                        Solution = solution,
                        DayIndex = dayIndex,
                        DayName = dayName
                    };
                }
            }
        }

        throw new InvalidOperationException($"Failed to generate Queens puzzle for day {dayIndex}");
    }

    private static int[]? RandomQueenPlacement(int size, Random rng)
    {
        var colUsed = new bool[size];
        var placement = new int[size];
        for (int i = 0; i < size; i++) placement[i] = -1;

        if (BacktrackPlace(size, 0, placement, colUsed, rng))
            return (int[])placement.Clone();
        return null;
    }

    private static bool BacktrackPlace(int size, int row, int[] placement, bool[] colUsed, Random rng)
    {
        if (row == size) return true;

        var cols = Enumerable.Range(0, size).ToArray();
        Shuffle(cols, rng);

        foreach (int col in cols)
        {
            if (colUsed[col]) continue;
            if (row > 0 && Math.Abs(col - placement[row - 1]) <= 1) continue;

            placement[row] = col;
            colUsed[col] = true;

            if (BacktrackPlace(size, row + 1, placement, colUsed, rng))
                return true;

            colUsed[col] = false;
            placement[row] = -1;
        }
        return false;
    }

    /// <summary>
    /// Generate zones using BFS expansion from queen positions (Voronoi-style).
    /// </summary>
    private static int[][] GenerateZones(int size, int[] solution, Random rng)
    {
        var zones = new int[size][];
        for (int r = 0; r < size; r++)
        {
            zones[r] = new int[size];
            Array.Fill(zones[r], -1);
        }

        var queues = new List<(int r, int c)>[size];
        for (int r = 0; r < size; r++)
        {
            zones[r][solution[r]] = r;
            queues[r] = [(r, solution[r])];
        }

        int unassigned = size * size - size;

        while (unassigned > 0)
        {
            bool progress = false;

            for (int z = 0; z < size; z++)
            {
                if (queues[z].Count == 0) continue;

                bool expanded = false;
                var nextQueue = new List<(int r, int c)>();

                while (queues[z].Count > 0 && !expanded)
                {
                    var (cr, cc) = queues[z][0];
                    queues[z].RemoveAt(0);

                    var shuffledDirs = Dirs.ToArray();
                    Shuffle(shuffledDirs, rng);

                    foreach (var dir in shuffledDirs)
                    {
                        int nr = cr + dir[0], nc = cc + dir[1];
                        if (nr >= 0 && nr < size && nc >= 0 && nc < size && zones[nr][nc] == -1)
                        {
                            zones[nr][nc] = z;
                            nextQueue.Add((nr, nc));
                            unassigned--;
                            expanded = true;
                            break;
                        }
                    }

                    if (!expanded)
                        nextQueue.Add((cr, cc));
                }

                queues[z] = [.. nextQueue, .. queues[z]];
                if (expanded) progress = true;
            }

            if (!progress)
            {
                for (int r = 0; r < size; r++)
                {
                    for (int c = 0; c < size; c++)
                    {
                        if (zones[r][c] != -1) continue;
                        foreach (var dir in Dirs)
                        {
                            int nr = r + dir[0], nc = c + dir[1];
                            if (nr >= 0 && nr < size && nc >= 0 && nc < size && zones[nr][nc] != -1)
                            {
                                zones[r][c] = zones[nr][nc];
                                unassigned--;
                                break;
                            }
                        }
                    }
                }
                if (unassigned <= 0) break;
            }
        }

        return zones;
    }

    private static bool HasAllZones(int[][] zones, int size)
    {
        var found = new HashSet<int>();
        for (int r = 0; r < size; r++)
            for (int c = 0; c < size; c++)
                found.Add(zones[r][c]);
        return found.Count == size;
    }

    private static bool ZonesConnected(int[][] zones, int size)
    {
        for (int z = 0; z < size; z++)
        {
            var cells = new List<(int r, int c)>();
            for (int r = 0; r < size; r++)
                for (int c = 0; c < size; c++)
                    if (zones[r][c] == z) cells.Add((r, c));

            if (cells.Count == 0) return false;

            var visited = new HashSet<(int, int)> { cells[0] };
            var queue = new Queue<(int r, int c)>();
            queue.Enqueue(cells[0]);

            while (queue.Count > 0)
            {
                var (cr, cc) = queue.Dequeue();
                foreach (var dir in Dirs)
                {
                    int nr = cr + dir[0], nc = cc + dir[1];
                    if (nr >= 0 && nr < size && nc >= 0 && nc < size
                        && zones[nr][nc] == z && !visited.Contains((nr, nc)))
                    {
                        visited.Add((nr, nc));
                        queue.Enqueue((nr, nc));
                    }
                }
            }

            if (visited.Count != cells.Count) return false;
        }
        return true;
    }

    private static void Shuffle<T>(T[] array, Random rng)
    {
        for (int i = array.Length - 1; i > 0; i--)
        {
            int j = rng.Next(i + 1);
            (array[i], array[j]) = (array[j], array[i]);
        }
    }
}
