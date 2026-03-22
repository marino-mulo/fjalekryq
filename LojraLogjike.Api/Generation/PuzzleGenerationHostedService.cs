namespace LojraLogjike.Api.Generation;

/// <summary>
/// Background service that automatically generates next week's puzzles.
/// Runs only on Sundays — checks every 12 hours so it's guaranteed to run at least once on Sunday.
/// </summary>
public class PuzzleGenerationHostedService : BackgroundService
{
    private readonly ILogger<PuzzleGenerationHostedService> _logger;
    private static readonly TimeSpan CheckInterval = TimeSpan.FromHours(12);

    public PuzzleGenerationHostedService(ILogger<PuzzleGenerationHostedService> logger)
    {
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (DateTime.Now.DayOfWeek == DayOfWeek.Sunday)
                {
                    await TryGenerateNextWeek();
                }
                else
                {
                    _logger.LogInformation("Skipping puzzle generation — today is {Day}, will generate on Sunday",
                        DateTime.Now.DayOfWeek);
                }
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

        var allExist = true;

        for (var day = 0; day < 7; day++)
        {
            var puzzle = PuzzleFileStore.LoadPuzzle<object>(nextMonday, "wordle7", day);
            if (puzzle == null)
            {
                allExist = false;
                break;
            }
        }

        if (allExist)
            return;

        _logger.LogInformation("Sunday auto-generation: generating puzzles for week {WeekKey}...", nextMonday);

        await WeeklyPuzzleGenerator.GenerateWeek(nextMonday);

        _logger.LogInformation("Puzzle generation complete for week {WeekKey}", nextMonday);
    }

    private static string GetNextMondayKey()
    {
        var now = DateTime.Now;
        var daysUntilMonday = ((int)DayOfWeek.Monday - (int)now.DayOfWeek + 7) % 7;
        if (daysUntilMonday == 0) daysUntilMonday = 7;
        var monday = now.AddDays(daysUntilMonday);
        return $"{monday.Year}-{monday.Month:D2}-{monday.Day:D2}";
    }
}
