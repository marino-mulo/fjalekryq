namespace LojraLogjike.Api.Games.Snake;

/// <summary>
/// Generates Snake puzzles with guaranteed unique solutions.
/// Uses shorter, winding paths and reveals "given" cells (anchor points with step numbers)
/// to ensure the puzzle has exactly one solution.
/// </summary>
public static class SnakeGenerator
{
    private static readonly int[] DaySizes = [5, 5, 6, 6, 7, 7, 7];
    private static readonly int[][] Dirs = [[0, 1], [1, 0], [0, -1], [-1, 0]];

    public static SnakePuzzle Generate(int seed, int dayIndex, string dayName)
    {
        int size = DaySizes[Math.Clamp(dayIndex, 0, 6)];
        int maxGivens = size switch { 5 => 4, 6 => 5, 7 => 7, _ => size };

        for (int seedOffset = 0; seedOffset < 200; seedOffset++)
        {
            var rng = new Random(seed + seedOffset * 31337);
            int attempts = size <= 5 ? 600 : size <= 6 ? 1000 : 1500;

            for (int attempt = 0; attempt < attempts; attempt++)
            {
                var path = BuildSnakePath(size, rng);
                if (path == null) continue;

                var solution = new int[size][];
                var rowClues = new int[size];
                var colClues = new int[size];
                for (int r = 0; r < size; r++) solution[r] = new int[size];

                for (int i = 0; i < path.Count; i++)
                {
                    solution[path[i].r][path[i].c] = i + 1;
                    rowClues[path[i].r]++;
                    colClues[path[i].c]++;
                }

                // Need variety in clues
                if (new HashSet<int>(rowClues).Count < 2 || new HashSet<int>(colClues).Count < 2) continue;

                var head = path[0];
                var tail = path[^1];

                // Try with increasing number of givens until unique
                for (int numGivens = 1; numGivens <= maxGivens; numGivens++)
                {
                    var givens = SelectGivens(path, numGivens);

                    int solCount = SnakeSolver.CountSolutions(rowClues, colClues,
                        head.r, head.c, tail.r, tail.c, size, path.Count, givens, 2);

                    Console.WriteLine($"[Snake] seed={seed}+{seedOffset} att={attempt} len={path.Count} givens={numGivens} sol={solCount}");

                    if (solCount == 1)
                    {
                        Console.WriteLine($"[Snake] SUCCESS! day={dayIndex} size={size} len={path.Count} givens={numGivens}");
                        return new SnakePuzzle
                        {
                            Size = size,
                            RowClues = rowClues,
                            ColClues = colClues,
                            HeadRow = head.r,
                            HeadCol = head.c,
                            TailRow = tail.r,
                            TailCol = tail.c,
                            SnakeLength = path.Count,
                            Givens = givens,
                            Solution = solution,
                            DayIndex = dayIndex,
                            DayName = dayName
                        };
                    }

                    // 0 means our own solution is invalid — bug, skip path
                    if (solCount == 0) break;
                    // -1 (node limit) or >1 (multiple solutions): try more givens
                }
            }
        }

        throw new InvalidOperationException($"Failed to generate Snake puzzle for day {dayIndex}");
    }

    /// <summary>
    /// Select evenly-spaced cells along the path as givens (excluding head and tail).
    /// </summary>
    private static int[][] SelectGivens(List<(int r, int c)> path, int count)
    {
        int available = path.Count - 2; // exclude head (index 0) and tail (last index)
        if (count > available) count = available;

        var result = new List<int[]>();
        var usedIndices = new HashSet<int>();
        double step = (path.Count - 1.0) / (count + 1.0);

        for (int i = 1; i <= count; i++)
        {
            int idx = (int)Math.Round(step * i);
            idx = Math.Clamp(idx, 1, path.Count - 2);

            // Resolve collisions by shifting forward then backward
            int orig = idx;
            while (usedIndices.Contains(idx) && idx < path.Count - 2) idx++;
            if (usedIndices.Contains(idx))
            {
                idx = orig;
                while (usedIndices.Contains(idx) && idx > 1) idx--;
            }

            if (usedIndices.Add(idx))
            {
                result.Add([path[idx].r, path[idx].c, idx + 1]); // +1 for 1-based step
            }
        }

        return result.ToArray();
    }

    private static List<(int r, int c)>? BuildSnakePath(int size, Random rng)
    {
        // Shorter snakes = more likely to have unique solutions
        int targetLen = size switch
        {
            5 => rng.Next(9, 13),   // 9-12 cells out of 25
            6 => rng.Next(12, 17),  // 12-16 cells out of 36
            7 => rng.Next(16, 22),  // 16-21 cells out of 49
            _ => rng.Next(size * size / 3, size * size / 2)
        };

        // Start on an edge for more constraining puzzles
        int startR, startC;
        int edge = rng.Next(4);
        switch (edge)
        {
            case 0: startR = 0; startC = rng.Next(size); break;
            case 1: startR = size - 1; startC = rng.Next(size); break;
            case 2: startR = rng.Next(size); startC = 0; break;
            default: startR = rng.Next(size); startC = size - 1; break;
        }

        var path = new List<(int r, int c)> { (startR, startC) };
        var occupied = new bool[size, size];
        occupied[startR, startC] = true;
        int lastDir = -1;

        for (int step = 1; step < targetLen; step++)
        {
            var (cr, cc) = path[^1];
            var candidates = new List<(int r, int c, int dir)>();

            for (int d = 0; d < 4; d++)
            {
                int nr = cr + Dirs[d][0];
                int nc = cc + Dirs[d][1];
                if ((uint)nr >= (uint)size || (uint)nc >= (uint)size) continue;
                if (occupied[nr, nc]) continue;
                if (HasOrthoTouch(occupied, nr, nc, cr, cc, size)) continue;
                candidates.Add((nr, nc, d));
            }

            if (candidates.Count == 0) break;

            // Prefer turns (70%) over straight lines — creates more winding paths
            (int r, int c, int dir) chosen;
            if (lastDir >= 0 && candidates.Count > 1)
            {
                var turns = candidates.Where(c => c.dir != lastDir).ToList();
                if (turns.Count > 0 && rng.Next(100) < 70)
                    chosen = turns[rng.Next(turns.Count)];
                else
                    chosen = candidates[rng.Next(candidates.Count)];
            }
            else
            {
                chosen = candidates[rng.Next(candidates.Count)];
            }

            path.Add((chosen.r, chosen.c));
            occupied[chosen.r, chosen.c] = true;
            lastDir = chosen.dir;
        }

        int minLen = size switch { 5 => 9, 6 => 12, 7 => 16, _ => size * size / 3 };
        if (path.Count < minLen) return null;

        // Head and tail must be at least 2 apart
        var h = path[0];
        var t = path[^1];
        if (Math.Abs(h.r - t.r) + Math.Abs(h.c - t.c) < 2) return null;

        return path;
    }

    private static bool HasOrthoTouch(bool[,] occ, int nr, int nc, int prevR, int prevC, int size)
    {
        if (nr > 0 && occ[nr - 1, nc] && !(nr - 1 == prevR && nc == prevC)) return true;
        if (nr < size - 1 && occ[nr + 1, nc] && !(nr + 1 == prevR && nc == prevC)) return true;
        if (nc > 0 && occ[nr, nc - 1] && !(nr == prevR && nc - 1 == prevC)) return true;
        if (nc < size - 1 && occ[nr, nc + 1] && !(nr == prevR && nc + 1 == prevC)) return true;
        return false;
    }
}
