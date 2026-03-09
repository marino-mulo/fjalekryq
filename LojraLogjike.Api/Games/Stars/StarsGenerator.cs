namespace LojraLogjike.Api.Games.Stars;

/// <summary>
/// Generates Stars puzzles with guaranteed unique solutions.
/// Algorithm: random star placement → proximity-based zone pairing → BFS expansion → verify uniqueness.
/// Stars: 2 per row, 2 per column, 2 per zone, no adjacent (including diagonals).
/// </summary>
public static class StarsGenerator
{
    private static readonly int[] DaySizes = [8, 8, 9, 9, 9, 9, 10];

    private static readonly int[][] Dirs = [[0, 1], [0, -1], [1, 0], [-1, 0]];

    /// <summary>
    /// Generate a Stars puzzle for a given seed and day.
    /// Tries multiple seed offsets if the initial seed doesn't produce a result.
    /// </summary>
    public static StarsPuzzle Generate(int seed, int dayIndex, string dayName)
    {
        int size = DaySizes[Math.Clamp(dayIndex, 0, 6)];

        for (int seedOffset = 0; seedOffset < 60; seedOffset++)
        {
            var rng = new Random(seed + seedOffset * 31337);

            int zonesPerPlacement = size <= 8 ? 10 : size <= 9 ? 15 : 20;
            int maxPlacements = size <= 8 ? 200 : size <= 9 ? 400 : 600;

            for (int p = 0; p < maxPlacements; p++)
            {
                var solution = RandomStarPlacement(size, rng);
                if (solution == null) continue;

                for (int z = 0; z < zonesPerPlacement; z++)
                {
                    var zones = GenerateZones(size, solution, rng);

                    if (!HasAllZones(zones, size)) continue;
                    if (!ZonesConnected(zones, size)) continue;
                    if (!ZonesHaveTwoStars(zones, size, solution)) continue;

                    // Pre-filter: zones with narrow column spans are much more likely
                    // to have unique solutions. Skips expensive uniqueness check early.
                    if (!ZonesAreConstraining(zones, size)) continue;

                    if (!StarsSolver.HasUniqueSolution(zones, size)) continue;

                    return new StarsPuzzle
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

        throw new InvalidOperationException($"Failed to generate Stars puzzle for day {dayIndex}");
    }

    /// <summary>
    /// Quick pre-filter: reject zones where any zone spans more than ~60% of the grid width.
    /// Narrow zones are far more likely to produce unique solutions.
    /// </summary>
    private static bool ZonesAreConstraining(int[][] zones, int size)
    {
        var zoneMinCol = new int[size];
        var zoneMaxCol = new int[size];
        Array.Fill(zoneMinCol, int.MaxValue);
        Array.Fill(zoneMaxCol, int.MinValue);

        for (int r = 0; r < size; r++)
            for (int c = 0; c < size; c++)
            {
                int z = zones[r][c];
                if (c < zoneMinCol[z]) zoneMinCol[z] = c;
                if (c > zoneMaxCol[z]) zoneMaxCol[z] = c;
            }

        int maxSpan = (size * 6 + 9) / 10; // ~60% of width
        for (int z = 0; z < size; z++)
            if (zoneMaxCol[z] - zoneMinCol[z] >= maxSpan) return false;
        return true;
    }

    /// <summary>
    /// Generate a random valid star placement via backtracking.
    /// 2 stars per row, 2 per col, no adjacent (including diagonal, including same-row adjacency).
    /// </summary>
    private static int[][]? RandomStarPlacement(int size, Random rng)
    {
        var colCount = new int[size];
        var placement = new int[size][];
        for (int i = 0; i < size; i++) placement[i] = [-1, -1];

        if (BacktrackPlace(size, 0, placement, colCount, rng))
            return placement.Select(p => (int[])p.Clone()).ToArray();
        return null;
    }

    private static bool BacktrackPlace(int size, int row, int[][] placement, int[] colCount, Random rng)
    {
        if (row == size) return true;

        // Generate all valid (c1, c2) pairs for this row
        var pairs = new List<(int c1, int c2)>();
        for (int c1 = 0; c1 < size - 1; c1++)
        {
            if (colCount[c1] >= 2) continue;
            if (row > 0 && IsAdjacentToPrevRow(c1, placement[row - 1])) continue;

            for (int c2 = c1 + 1; c2 < size; c2++)
            {
                if (colCount[c2] >= 2) continue;
                if (c2 - c1 <= 1) continue; // same-row adjacency
                if (row > 0 && IsAdjacentToPrevRow(c2, placement[row - 1])) continue;
                pairs.Add((c1, c2));
            }
        }

        // Shuffle pairs
        Shuffle(pairs, rng);

        foreach (var (c1, c2) in pairs)
        {
            placement[row][0] = c1;
            placement[row][1] = c2;
            colCount[c1]++;
            colCount[c2]++;

            if (BacktrackPlace(size, row + 1, placement, colCount, rng))
                return true;

            colCount[c1]--;
            colCount[c2]--;
            placement[row][0] = -1;
            placement[row][1] = -1;
        }
        return false;
    }

    /// <summary>
    /// Generate zones using proximity-based star pairing + BFS expansion.
    /// Stars are paired using greedy nearest-neighbor matching to create compact zones.
    /// </summary>
    private static int[][] GenerateZones(int size, int[][] solution, Random rng)
    {
        var zones = new int[size][];
        for (int r = 0; r < size; r++)
        {
            zones[r] = new int[size];
            Array.Fill(zones[r], -1);
        }

        // Pair stars: 70% of the time use same-column pairing (creates narrow column-aligned zones),
        // 30% of the time use proximity pairing (creates variety).
        List<((int r, int c) s1, (int r, int c) s2)> pairs;
        if (rng.Next(10) < 7)
            pairs = PairStarsBySameColumn(solution, size, rng);
        else
        {
            var stars = new List<(int r, int c)>();
            for (int r = 0; r < size; r++) { stars.Add((r, solution[r][0])); stars.Add((r, solution[r][1])); }
            pairs = PairStarsByProximity(stars, rng);
        }

        var queues = new List<(int r, int c)>[size];
        for (int z = 0; z < size; z++)
        {
            var (s1, s2) = pairs[z];
            zones[s1.r][s1.c] = z;
            zones[s2.r][s2.c] = z;
            queues[z] = [s1, s2];
        }

        int unassigned = size * size - 2 * size;

        while (unassigned > 0)
        {
            bool progress = false;

            // Randomize zone expansion order
            var zoneOrder = Enumerable.Range(0, size).ToList();
            Shuffle(zoneOrder, rng);

            foreach (int z in zoneOrder)
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

    /// <summary>
    /// Pair 2N stars into N pairs using greedy proximity matching.
    /// Adds randomness by sometimes picking the 2nd or 3rd closest instead of the closest.
    /// </summary>
    private static List<((int r, int c) s1, (int r, int c) s2)> PairStarsByProximity(
        List<(int r, int c)> stars, Random rng)
    {
        var available = new List<(int r, int c)>(stars);
        Shuffle(available, rng);
        var pairs = new List<((int r, int c), (int r, int c))>();

        while (available.Count >= 2)
        {
            // Pick a random star
            int idx = rng.Next(available.Count);
            var s1 = available[idx];
            available.RemoveAt(idx);

            // Find closest stars and pick one with some randomness
            var sorted = available.OrderBy(s =>
                Math.Abs(s.r - s1.r) + Math.Abs(s.c - s1.c)).ToList();

            // Pick among the top few closest (with bias toward closer)
            int pickRange = Math.Min(3, sorted.Count);
            int pick = rng.Next(pickRange);
            var s2 = sorted[pick];
            available.Remove(s2);

            pairs.Add((s1, s2));
        }

        return pairs;
    }

    /// <summary>
    /// Pair the 2 stars in each column together. Since there are exactly 2 stars per column,
    /// this creates zones naturally aligned along columns — much more constraining.
    /// Zone IDs are shuffled so zone 0 isn't always column 0.
    /// </summary>
    private static List<((int r, int c) s1, (int r, int c) s2)> PairStarsBySameColumn(
        int[][] solution, int size, Random rng)
    {
        var pairs = new List<((int r, int c), (int r, int c))>();

        // Group by column
        var byCol = new List<(int r, int c)>[size];
        for (int c = 0; c < size; c++) byCol[c] = new List<(int r, int c)>();
        for (int r = 0; r < size; r++)
        {
            byCol[solution[r][0]].Add((r, solution[r][0]));
            byCol[solution[r][1]].Add((r, solution[r][1]));
        }

        // Each column has exactly 2 stars — pair them
        var colOrder = Enumerable.Range(0, size).ToList();
        Shuffle(colOrder, rng);
        foreach (int col in colOrder)
        {
            if (byCol[col].Count == 2)
                pairs.Add((byCol[col][0], byCol[col][1]));
        }
        return pairs;
    }

    private static bool HasAllZones(int[][] zones, int size)
    {
        var found = new HashSet<int>();
        for (int r = 0; r < size; r++)
            for (int c = 0; c < size; c++)
                found.Add(zones[r][c]);
        return found.Count == size;
    }

    /// <summary>
    /// Verify each zone has exactly 2 stars from the solution.
    /// </summary>
    private static bool ZonesHaveTwoStars(int[][] zones, int size, int[][] solution)
    {
        var zoneCounts = new int[size];
        for (int r = 0; r < size; r++)
        {
            zoneCounts[zones[r][solution[r][0]]]++;
            zoneCounts[zones[r][solution[r][1]]]++;
        }
        for (int z = 0; z < size; z++)
        {
            if (zoneCounts[z] != 2) return false;
        }
        return true;
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

    private static bool IsAdjacentToPrevRow(int col, int[] prevRowStars)
    {
        return Math.Abs(col - prevRowStars[0]) <= 1 || Math.Abs(col - prevRowStars[1]) <= 1;
    }

    private static void Shuffle<T>(T[] array, Random rng)
    {
        for (int i = array.Length - 1; i > 0; i--)
        {
            int j = rng.Next(i + 1);
            (array[i], array[j]) = (array[j], array[i]);
        }
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
