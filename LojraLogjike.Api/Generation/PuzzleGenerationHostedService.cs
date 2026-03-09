namespace LojraLogjike.Api.Generation;

/// <summary>
/// Background service that automatically generates next week's puzzles.
/// - On startup: checks if next week's puzzles exist, generates if missing.
/// - Every hour: checks again (catches Sunday rollover automatically).
/// </summary>
public class PuzzleGenerationHostedService : BackgroundService
{
    private readonly ILogger<PuzzleGenerationHostedService> _logger;
    private static readonly TimeSpan CheckInterval = TimeSpan.FromHours(1);

    public PuzzleGenerationHostedService(ILogger<PuzzleGenerationHostedService> logger)
    {
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Small delay on startup to let the web server initialize first
        await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await TryGenerateNextWeek();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during automatic puzzle generation");
            }

            await Task.Delay(CheckInterval, stoppingToken);
        }
    }

    private async Task TryGenerateNextWeek()
    {
        var nextMonday = GetNextMondayKey();

        // Check if all 42 puzzles already exist
        var allExist = true;
        string[] games = ["snake", "zip", "queens", "stars", "tango", "wordle7"];

        foreach (var game in games)
        {
            for (var day = 0; day < 7; day++)
            {
                var puzzle = PuzzleFileStore.LoadPuzzle<object>(nextMonday, game, day);
                if (puzzle == null)
                {
                    allExist = false;
                    break;
                }
            }
            if (!allExist) break;
        }

        if (allExist)
            return; // Nothing to do

        _logger.LogInformation("Auto-generating puzzles for week {WeekKey}...", nextMonday);

        await WeeklyPuzzleGenerator.GenerateWeek(nextMonday);

        _logger.LogInformation("Puzzle generation complete for week {WeekKey}", nextMonday);
    }

    /// <summary>
    /// Get the next Monday's date as "YYYY-MM-DD".
    /// If today is Monday, returns next Monday (current week puzzles should already exist).
    /// </summary>
    private static string GetNextMondayKey()
    {
        var now = DateTime.Now;
        var daysUntilMonday = ((int)DayOfWeek.Monday - (int)now.DayOfWeek + 7) % 7;
        if (daysUntilMonday == 0) daysUntilMonday = 7;
        var monday = now.AddDays(daysUntilMonday);
        return $"{monday.Year}-{monday.Month:D2}-{monday.Day:D2}";
    }
}
