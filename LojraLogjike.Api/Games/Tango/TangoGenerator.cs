namespace LojraLogjike.Api.Games.Tango;

/// <summary>
/// Generates Tango puzzles with guaranteed unique solutions.
/// Uses a minimization approach: starts fully filled, removes cells while maintaining uniqueness.
/// Seeded randomness ensures deterministic daily puzzles.
/// </summary>
public static class TangoGenerator
{
    private const int Size = 6;
    private const int Empty = -1;
    private const int Sun = 0;
    private const int Moon = 1;

    /// <summary>
    /// Difficulty settings per day (0=Monday easiest → 6=Sunday hardest).
    /// minPrefilled/maxPrefilled = target range for prefilled symbol count (4-6).
    /// targetConstraints = number of = / × hints to start with.
    /// maxConstraints = hard cap on total constraints allowed.
    /// </summary>
    private static readonly (int minPrefilled, int maxPrefilled, int targetConstraints, int maxConstraints)[] DifficultyLevels =
    [
        (5, 6, 8, 8),  // Monday    — easy
        (5, 6, 7, 8),  // Tuesday   — easy-medium
        (4, 6, 7, 8),  // Wednesday — medium
        (4, 5, 7, 8),  // Thursday  — medium
        (4, 5, 6, 7),  // Friday    — medium-hard
        (4, 5, 6, 7),  // Saturday  — hard
        (4, 5, 5, 7),  // Sunday    — hardest
    ];

    /// <summary>
    /// Generate a puzzle for a given seed and day index.
    /// </summary>
    public static TangoPuzzle Generate(int seed, int dayIndex, string dayName)
    {
        var (minPrefilled, maxPrefilled, targetConstraints, maxConstraints) = DifficultyLevels[Math.Clamp(dayIndex, 0, 6)];
        var rng = new Random(seed);

        for (int attempt = 0; attempt < 100; attempt++)
        {
            var result = TryGenerate(rng, minPrefilled, maxPrefilled, targetConstraints, maxConstraints);
            if (result != null)
            {
                return new TangoPuzzle
                {
                    Solution = result.Value.solution,
                    Prefilled = result.Value.prefilled,
                    Constraints = result.Value.constraints,
                    DayIndex = dayIndex,
                    DayName = dayName
                };
            }
        }

        // Fallback: generate with relaxed targets
        return GenerateFallback(rng, dayIndex, dayName);
    }

    private static (int[][] solution, int[][] prefilled, TangoConstraint[] constraints)? TryGenerate(
        Random rng, int minPrefilled, int maxPrefilled, int targetConstraints, int maxConstraints)
    {
        // Step 1: Generate a valid complete solution
        var solution = GenerateSolution(rng);
        if (solution == null) return null;

        // Step 2: Pick constraint positions between adjacent cells
        var allPairs = GetAllAdjacentPairs();
        Shuffle(allPairs, rng);

        // Select constraints, preferring a good spread across the board
        var constraints = SelectConstraints(solution, allPairs, targetConstraints, rng);
        var constraintArray = constraints.ToArray();

        // Step 3: Minimization approach — start fully filled, remove cells
        var prefilled = new int[Size][];
        for (int r = 0; r < Size; r++)
            prefilled[r] = (int[])solution[r].Clone();

        // Shuffle cell removal order for variety
        var cells = GetAllCells();
        Shuffle(cells, rng);

        // Track which cells are still prefilled
        var prefilledSet = new HashSet<(int r, int c)>(cells);

        // Try removing each cell; keep removal if puzzle stays unique
        foreach (var (r, c) in cells)
        {
            if (prefilledSet.Count <= minPrefilled)
                break;

            int saved = prefilled[r][c];
            prefilled[r][c] = Empty;

            if (TangoSolver.HasUniqueSolution(prefilled, constraintArray))
            {
                prefilledSet.Remove((r, c));
            }
            else
            {
                prefilled[r][c] = saved;
            }
        }

        int count = prefilledSet.Count;

        // Check if we're in target range
        if (count >= minPrefilled && count <= maxPrefilled)
            return (solution, prefilled, constraintArray);

        // If too many prefilled, try adding more constraints (up to cap) and removing again
        if (count > maxPrefilled)
        {
            for (int i = 0; i < allPairs.Count && constraints.Count < maxConstraints; i++)
            {
                var (r1, c1, r2, c2) = allPairs[i];
                if (constraints.Any(ct => ct.R1 == r1 && ct.C1 == c1 && ct.R2 == r2 && ct.C2 == c2))
                    continue;

                var type = solution[r1][c1] == solution[r2][c2] ? "same" : "diff";
                constraints.Add(new TangoConstraint { R1 = r1, C1 = c1, R2 = r2, C2 = c2, Type = type });
            }
            constraintArray = constraints.ToArray();

            // Try another round of removal
            Shuffle(cells, rng);
            foreach (var (r, c) in cells)
            {
                if (prefilled[r][c] == Empty) continue;
                if (prefilledSet.Count <= minPrefilled) break;

                int saved = prefilled[r][c];
                prefilled[r][c] = Empty;

                if (TangoSolver.HasUniqueSolution(prefilled, constraintArray))
                {
                    prefilledSet.Remove((r, c));
                }
                else
                {
                    prefilled[r][c] = saved;
                }
            }

            count = prefilledSet.Count;
            if (count >= minPrefilled && count <= maxPrefilled)
                return (solution, prefilled, constraintArray);
        }

        return null; // Not in range — retry with a different solution
    }

    /// <summary>
    /// Select constraints with good spatial distribution.
    /// </summary>
    private static List<TangoConstraint> SelectConstraints(
        int[][] solution, List<(int r1, int c1, int r2, int c2)> pairs, int count, Random rng)
    {
        var selected = new List<TangoConstraint>();
        var usedCells = new HashSet<(int, int)>();

        // First pass: prefer constraints that don't share cells
        foreach (var (r1, c1, r2, c2) in pairs)
        {
            if (selected.Count >= count) break;
            if (usedCells.Contains((r1, c1)) || usedCells.Contains((r2, c2))) continue;

            var type = solution[r1][c1] == solution[r2][c2] ? "same" : "diff";
            selected.Add(new TangoConstraint { R1 = r1, C1 = c1, R2 = r2, C2 = c2, Type = type });
            usedCells.Add((r1, c1));
            usedCells.Add((r2, c2));
        }

        // Second pass: fill remaining slots allowing shared cells
        if (selected.Count < count)
        {
            foreach (var (r1, c1, r2, c2) in pairs)
            {
                if (selected.Count >= count) break;
                if (selected.Any(ct => ct.R1 == r1 && ct.C1 == c1 && ct.R2 == r2 && ct.C2 == c2))
                    continue;

                var type = solution[r1][c1] == solution[r2][c2] ? "same" : "diff";
                selected.Add(new TangoConstraint { R1 = r1, C1 = c1, R2 = r2, C2 = c2, Type = type });
            }
        }

        return selected;
    }

    private static TangoPuzzle GenerateFallback(Random rng, int dayIndex, string dayName)
    {
        for (int fallback = 0; fallback < 200; fallback++)
        {
            var solution = GenerateSolution(rng);
            if (solution == null) continue;

            var allPairs = GetAllAdjacentPairs();
            Shuffle(allPairs, rng);

            var constraints = SelectConstraints(solution, allPairs, 8, rng);
            var constraintArray = constraints.ToArray();

            var prefilled = new int[Size][];
            for (int r = 0; r < Size; r++)
                prefilled[r] = (int[])solution[r].Clone();

            var cells = GetAllCells();
            Shuffle(cells, rng);
            var prefilledSet = new HashSet<(int r, int c)>(cells);

            foreach (var (r, c) in cells)
            {
                if (prefilledSet.Count <= 4) break;

                int saved = prefilled[r][c];
                prefilled[r][c] = Empty;

                if (TangoSolver.HasUniqueSolution(prefilled, constraintArray))
                    prefilledSet.Remove((r, c));
                else
                    prefilled[r][c] = saved;
            }

            return new TangoPuzzle
            {
                Solution = solution,
                Prefilled = prefilled,
                Constraints = constraintArray,
                DayIndex = dayIndex,
                DayName = dayName
            };
        }

        throw new InvalidOperationException("Failed to generate Tango puzzle");
    }

    private static int[][]? GenerateSolution(Random rng)
    {
        var board = new int[Size][];
        for (int r = 0; r < Size; r++)
            board[r] = Enumerable.Repeat(Empty, Size).ToArray();

        if (FillBoard(board, 0, rng))
            return board;
        return null;
    }

    private static bool FillBoard(int[][] board, int pos, Random rng)
    {
        if (pos == Size * Size) return true;

        int row = pos / Size;
        int col = pos % Size;

        int first = rng.Next(2) == 0 ? Sun : Moon;
        int second = first == Sun ? Moon : Sun;

        foreach (int val in new[] { first, second })
        {
            board[row][col] = val;
            if (IsValidPlacement(board, row, col))
            {
                if (FillBoard(board, pos + 1, rng))
                    return true;
            }
            board[row][col] = Empty;
        }
        return false;
    }

    private static bool IsValidPlacement(int[][] board, int row, int col)
    {
        int val = board[row][col];

        int rowCount = 0;
        for (int c = 0; c < Size; c++)
            if (board[row][c] == val) rowCount++;
        if (rowCount > 3) return false;

        int colCount = 0;
        for (int r = 0; r < Size; r++)
            if (board[r][col] == val) colCount++;
        if (colCount > 3) return false;

        if (col >= 2 && board[row][col - 1] == val && board[row][col - 2] == val) return false;
        if (col >= 1 && col < Size - 1 && board[row][col - 1] == val && board[row][col + 1] == val) return false;
        if (col < Size - 2 && board[row][col + 1] == val && board[row][col + 2] == val) return false;

        if (row >= 2 && board[row - 1][col] == val && board[row - 2][col] == val) return false;
        if (row >= 1 && row < Size - 1 && board[row - 1][col] == val && board[row + 1][col] == val) return false;
        if (row < Size - 2 && board[row + 1][col] == val && board[row + 2][col] == val) return false;

        return true;
    }

    private static List<(int r1, int c1, int r2, int c2)> GetAllAdjacentPairs()
    {
        var pairs = new List<(int, int, int, int)>();
        for (int r = 0; r < Size; r++)
            for (int c = 0; c < Size; c++)
            {
                if (c + 1 < Size) pairs.Add((r, c, r, c + 1));
                if (r + 1 < Size) pairs.Add((r, c, r + 1, c));
            }
        return pairs;
    }

    private static List<(int r, int c)> GetAllCells()
    {
        var cells = new List<(int, int)>();
        for (int r = 0; r < Size; r++)
            for (int c = 0; c < Size; c++)
                cells.Add((r, c));
        return cells;
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
