// using LojraLogjike.Api.Email; // TODO: Uncomment when email subscription is needed
using LojraLogjike.Api.Generation;

// ── CLI Commands ──
if (args.Length > 0 && args[0] == "generate-week")
{
    string? weekKey = args.Length > 1 ? args[1] : null;
    await WeeklyPuzzleGenerator.GenerateWeek(weekKey);
    return;
}

// ── Normal Web API ──
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddHostedService<PuzzleGenerationHostedService>();
// builder.Services.AddHostedService<DailyEmailHostedService>(); // TODO: Uncomment when email subscription is needed
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins("http://localhost:4200")
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

var app = builder.Build();

app.UseCors();
app.MapControllers();

app.Run();
