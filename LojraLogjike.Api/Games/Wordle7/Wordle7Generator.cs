namespace LojraLogjike.Api.Games.Wordle7;

/// <summary>
/// Generates Wordle7 (crossword) puzzles using backtracking word placement.
/// Validates that all horizontal/vertical runs of 2+ letters are valid words (no ghost words).
/// Ensures all placed words are connected.
/// </summary>
public static class Wordle7Generator
{
    private static readonly (int size, int minWords, int minLetters, int attempts, string pool)[] DayConfigs =
    [
        (7,  8,  20, 800,  "small"),   // Monday
        (7,  9,  22, 800,  "small"),   // Tuesday
        (8,  10, 28, 1000, "medium"),  // Wednesday
        (8,  11, 30, 1000, "medium"),  // Thursday
        (9,  13, 35, 1200, "large"),   // Friday
        (9,  14, 38, 1200, "large"),   // Saturday
        (10, 16, 45, 1500, "large"),   // Sunday
    ];

    /// <summary>
    /// Generate a crossword puzzle for a given seed and day.
    /// </summary>
    public static Wordle7Puzzle Generate(int seed, int dayIndex, string dayName)
    {
        var cfg = DayConfigs[Math.Clamp(dayIndex, 0, 6)];
        var rng = new Random(seed);

        var result = GeneratePuzzle(rng, cfg.size, cfg.minWords, cfg.minLetters, cfg.attempts, cfg.pool);

        if (result == null)
        {
            // Fallback with relaxed requirements
            result = GeneratePuzzle(rng, cfg.size,
                Math.Max(3, cfg.minWords - 3),
                Math.Max(12, cfg.minLetters - 10),
                cfg.attempts * 2, cfg.pool);
        }

        if (result == null)
            throw new InvalidOperationException($"Failed to generate Wordle7 puzzle for day {dayIndex}");

        return new Wordle7Puzzle
        {
            GridSize = cfg.size,
            Solution = result.Value.grid,
            Words = result.Value.words,
            DayIndex = dayIndex,
            DayName = dayName
        };
    }

    private static (string[][] grid, WordEntry[] words)? GeneratePuzzle(
        Random rng, int size, int minWords, int minLetters, int maxAttempts, string poolName)
    {
        var pool = Wordle7Dictionary.GetPool(poolName);
        string[][] bestGrid = null!;
        WordEntry[] bestWords = null!;
        int bestScore = 0;

        for (int attempt = 0; attempt < maxAttempts; attempt++)
        {
            Shuffle(pool, rng);
            var grid = MakeGrid(size);
            var wordSet = new HashSet<string>();
            var placed = new List<(string word, int row, int col, string dir)>();

            // Place first word in center area
            string first = pool[0];
            if (first.Length > size) continue;
            int r = size / 2;
            int c = Math.Max(0, (size - first.Length) / 2);
            grid = TryPlace(grid, first, r, c, "horizontal", size);
            if (grid == null) continue;
            wordSet.Add(first);
            placed.Add((first, r, c, "horizontal"));

            // Try to add remaining words — multiple passes
            var remaining = pool.Where(w => !wordSet.Contains(w)).ToList();

            for (int pass = 0; pass < 3; pass++)
            {
                Shuffle(remaining, rng);
                var stillRemaining = new List<string>();
                foreach (string word in remaining)
                {
                    if (wordSet.Contains(word)) continue;
                    if (word.Length > size) { stillRemaining.Add(word); continue; }

                    var placements = FindAllPlacements(grid, word, wordSet, size);
                    if (placements.Count > 0)
                    {
                        var (pr, pc, pd, pg) = placements[rng.Next(placements.Count)];
                        grid = pg;
                        wordSet.Add(word);
                        placed.Add((word, pr, pc, pd));
                    }
                    else
                    {
                        stillRemaining.Add(word);
                    }
                }
                remaining = stillRemaining;
            }

            int nWords = placed.Count;
            int nLetters = CountLetters(grid);

            if (nWords >= minWords && nLetters >= minLetters && CheckConnectivity(placed))
            {
                // Clean placed words: remove any whose run doesn't match the actual grid
                var cleanPlaced = CleanPlacedWords(grid, placed, size);
                var finalWords = cleanPlaced.Select(p => new WordEntry
                {
                    Word = p.word, Row = p.row, Col = p.col, Direction = p.dir
                }).ToArray();

                int score = nWords * 10 + nLetters;
                if (score > bestScore)
                {
                    bestScore = score;
                    bestGrid = grid;
                    bestWords = finalWords;

                    if (nWords >= minWords + 4)
                        break;
                }
            }
        }

        if (bestGrid != null)
            return (bestGrid, bestWords);
        return null;
    }

    private static string[][] MakeGrid(int size)
    {
        var grid = new string[size][];
        for (int r = 0; r < size; r++)
        {
            grid[r] = new string[size];
            Array.Fill(grid[r], "X");
        }
        return grid;
    }

    private static string[][]? TryPlace(string[][] grid, string word, int row, int col, string direction, int size)
    {
        var g = grid.Select(r => (string[])r.Clone()).ToArray();
        for (int i = 0; i < word.Length; i++)
        {
            int r = row + (direction == "vertical" ? i : 0);
            int c = col + (direction == "horizontal" ? i : 0);
            if (r >= size || c >= size) return null;
            string ch = word[i].ToString();
            if (g[r][c] != "X" && g[r][c] != ch) return null;
            g[r][c] = ch;
        }
        return g;
    }

    private static bool WordSharesCell(string[][] grid, string word, int row, int col, string direction, int size)
    {
        for (int i = 0; i < word.Length; i++)
        {
            int r = row + (direction == "vertical" ? i : 0);
            int c = col + (direction == "horizontal" ? i : 0);
            if (r < size && c < size && grid[r][c] != "X")
                return true;
        }
        return false;
    }

    private static List<string> FindAllRuns(string[][] grid, int size)
    {
        var runs = new List<string>();

        // Horizontal runs
        for (int r = 0; r < size; r++)
        {
            int c = 0;
            while (c < size)
            {
                if (grid[r][c] != "X")
                {
                    string s = "";
                    while (c < size && grid[r][c] != "X")
                    {
                        s += grid[r][c];
                        c++;
                    }
                    if (s.Length >= 2) runs.Add(s);
                }
                else c++;
            }
        }

        // Vertical runs
        for (int c = 0; c < size; c++)
        {
            int r = 0;
            while (r < size)
            {
                if (grid[r][c] != "X")
                {
                    string s = "";
                    while (r < size && grid[r][c] != "X")
                    {
                        s += grid[r][c];
                        r++;
                    }
                    if (s.Length >= 2) runs.Add(s);
                }
                else r++;
            }
        }

        return runs;
    }

    private static bool IsValidAfterPlacement(string[][] grid, HashSet<string> wordSet, int size)
    {
        foreach (var run in FindAllRuns(grid, size))
        {
            if (!wordSet.Contains(run)) return false;
        }
        return true;
    }

    private static List<(int row, int col, string dir, string[][] grid)> FindAllPlacements(
        string[][] grid, string word, HashSet<string> wordSet, int size)
    {
        var placements = new List<(int, int, string, string[][])>();
        var newWs = new HashSet<string>(wordSet) { word };

        foreach (string direction in new[] { "horizontal", "vertical" })
        {
            int maxR = size - (direction == "vertical" ? word.Length : 1);
            int maxC = size - (direction == "horizontal" ? word.Length : 1);

            for (int r = 0; r <= maxR; r++)
            {
                for (int c = 0; c <= maxC; c++)
                {
                    var newGrid = TryPlace(grid, word, r, c, direction, size);
                    if (newGrid == null) continue;

                    // Must share at least one cell with existing letters (unless first word)
                    if (CountLetters(grid) > 0 && !WordSharesCell(grid, word, r, c, direction, size))
                        continue;

                    if (IsValidAfterPlacement(newGrid, newWs, size))
                        placements.Add((r, c, direction, newGrid));
                }
            }
        }
        return placements;
    }

    private static int CountLetters(string[][] grid)
    {
        int count = 0;
        foreach (var row in grid)
            foreach (var cell in row)
                if (cell != "X") count++;
        return count;
    }

    private static bool CheckConnectivity(List<(string word, int row, int col, string dir)> placed)
    {
        if (placed.Count <= 1) return true;

        var cellsPerWord = new List<HashSet<(int, int)>>();
        foreach (var (w, r, c, d) in placed)
        {
            var cells = new HashSet<(int, int)>();
            for (int i = 0; i < w.Length; i++)
            {
                int rr = r + (d == "vertical" ? i : 0);
                int cc = c + (d == "horizontal" ? i : 0);
                cells.Add((rr, cc));
            }
            cellsPerWord.Add(cells);
        }

        // Build adjacency graph: words are connected if they share any cell
        var adj = new Dictionary<int, HashSet<int>>();
        for (int i = 0; i < placed.Count; i++)
            adj[i] = [];

        for (int i = 0; i < placed.Count; i++)
        {
            for (int j = i + 1; j < placed.Count; j++)
            {
                if (cellsPerWord[i].Overlaps(cellsPerWord[j]))
                {
                    adj[i].Add(j);
                    adj[j].Add(i);
                }
            }
        }

        // BFS from word 0
        var visited = new HashSet<int> { 0 };
        var queue = new Queue<int>();
        queue.Enqueue(0);
        while (queue.Count > 0)
        {
            int n = queue.Dequeue();
            foreach (int nb in adj[n])
            {
                if (!visited.Contains(nb))
                {
                    visited.Add(nb);
                    queue.Enqueue(nb);
                }
            }
        }
        return visited.Count == placed.Count;
    }

    /// <summary>
    /// Remove placed words whose run in the actual grid doesn't match
    /// (e.g. a shorter word got extended by a longer one).
    /// </summary>
    private static List<(string word, int row, int col, string dir)> CleanPlacedWords(
        string[][] grid, List<(string word, int row, int col, string dir)> placed, int size)
    {
        var actualRuns = new HashSet<(string, int, int, string)>();

        // Horizontal runs
        for (int r = 0; r < size; r++)
        {
            int c = 0;
            while (c < size)
            {
                if (grid[r][c] != "X")
                {
                    int start = c;
                    string s = "";
                    while (c < size && grid[r][c] != "X")
                    {
                        s += grid[r][c];
                        c++;
                    }
                    if (s.Length >= 2) actualRuns.Add((s, r, start, "horizontal"));
                }
                else c++;
            }
        }

        // Vertical runs
        for (int c = 0; c < size; c++)
        {
            int r = 0;
            while (r < size)
            {
                if (grid[r][c] != "X")
                {
                    int start = r;
                    string s = "";
                    while (r < size && grid[r][c] != "X")
                    {
                        s += grid[r][c];
                        r++;
                    }
                    if (s.Length >= 2) actualRuns.Add((s, start, c, "vertical"));
                }
                else r++;
            }
        }

        var clean = new List<(string, int, int, string)>();
        var usedRuns = new HashSet<(string, int, int, string)>();
        foreach (var (word, row, col, dir) in placed)
        {
            var key = (word, row, col, dir);
            if (actualRuns.Contains(key) && !usedRuns.Contains(key))
            {
                clean.Add(key);
                usedRuns.Add(key);
            }
        }
        return clean;
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
