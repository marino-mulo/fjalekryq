// using LojraLogjike.Api.Email; // TODO: Uncomment when email subscription is needed
using LojraLogjike.Api.Middleware;

// ── Normal Web API ──
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
// builder.Services.AddHostedService<DailyEmailHostedService>(); // TODO: Uncomment when email subscription is needed

var allowedOrigins = builder.Configuration.GetSection("AllowedOrigins").Get<string[]>()
    ?? ["http://localhost:4200"];

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(allowedOrigins)
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

var app = builder.Build();

// Serve Angular static files from wwwroot
app.UseDefaultFiles();
app.UseStaticFiles();

app.UseCors();
app.UseMiddleware<ApiKeyMiddleware>();
app.MapControllers();

// SPA fallback: serve index.html for non-API, non-file routes
app.MapFallbackToFile("index.html");

app.Run();
