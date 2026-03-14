// TODO: Uncomment when email subscription is needed
/*
using System.Text.Json;

namespace LojraLogjike.Api.Email;

public record Subscriber(string Id, string Email, DateTime SubscribedAt, bool Active);

/// <summary>
/// Thread-safe JSON file store for email subscribers.
/// Stores data in Data/subscribers.json following the PuzzleFileStore pattern.
/// </summary>
public static class SubscriberStore
{
    private static readonly SemaphoreSlim Lock = new(1, 1);

    private static readonly JsonSerializerOptions WriteOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    private static readonly JsonSerializerOptions ReadOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    private static string? _dataRoot;

    private static string GetDataDirectory()
    {
        if (_dataRoot != null) return _dataRoot;

        // Try project root first (development)
        var projectDir = Path.Combine(AppContext.BaseDirectory, "..", "..", "..");
        var devPath = Path.GetFullPath(Path.Combine(projectDir, "Data"));
        if (Directory.Exists(Path.GetFullPath(projectDir)) && Directory.Exists(devPath) == false)
            Directory.CreateDirectory(devPath);

        if (Directory.Exists(devPath))
        {
            _dataRoot = devPath;
            return _dataRoot;
        }

        // Fall back to AppContext.BaseDirectory (production)
        var prodPath = Path.Combine(AppContext.BaseDirectory, "Data");
        Directory.CreateDirectory(prodPath);
        _dataRoot = prodPath;
        return _dataRoot;
    }

    private static string GetFilePath() => Path.Combine(GetDataDirectory(), "subscribers.json");
    private static string GetSentMarkerPath() => Path.Combine(GetDataDirectory(), "last_email_sent.txt");

    public static async Task<List<Subscriber>> LoadSubscribersAsync()
    {
        await Lock.WaitAsync();
        try
        {
            var path = GetFilePath();
            if (!File.Exists(path)) return [];

            var json = await File.ReadAllTextAsync(path);
            return JsonSerializer.Deserialize<List<Subscriber>>(json, ReadOptions) ?? [];
        }
        catch
        {
            return [];
        }
        finally
        {
            Lock.Release();
        }
    }

    private static async Task SaveSubscribersAsync(List<Subscriber> subscribers)
    {
        var dir = GetDataDirectory();
        Directory.CreateDirectory(dir);
        var json = JsonSerializer.Serialize(subscribers, WriteOptions);
        await File.WriteAllTextAsync(GetFilePath(), json);
    }

    public static async Task<(bool success, string message)> AddSubscriberAsync(string email)
    {
        await Lock.WaitAsync();
        try
        {
            var subscribers = await LoadSubscribersInternalAsync();
            var existing = subscribers.Find(s => s.Email.Equals(email, StringComparison.OrdinalIgnoreCase));

            if (existing != null)
            {
                if (existing.Active)
                    return (true, "U regjistruat me sukses!");

                // Reactivate
                var index = subscribers.IndexOf(existing);
                subscribers[index] = existing with { Active = true, SubscribedAt = DateTime.Now };
                await SaveSubscribersAsync(subscribers);
                return (true, "U regjistruat me sukses!");
            }

            var subscriber = new Subscriber(
                Id: Guid.NewGuid().ToString(),
                Email: email.Trim().ToLowerInvariant(),
                SubscribedAt: DateTime.Now,
                Active: true
            );
            subscribers.Add(subscriber);
            await SaveSubscribersAsync(subscribers);
            return (true, "U regjistruat me sukses!");
        }
        finally
        {
            Lock.Release();
        }
    }

    public static async Task<(bool success, string message)> RemoveSubscriberAsync(string email)
    {
        await Lock.WaitAsync();
        try
        {
            var subscribers = await LoadSubscribersInternalAsync();
            var existing = subscribers.Find(s =>
                s.Email.Equals(email, StringComparison.OrdinalIgnoreCase) && s.Active);

            if (existing == null)
                return (false, "Ky email nuk është i regjistruar.");

            var index = subscribers.IndexOf(existing);
            subscribers[index] = existing with { Active = false };
            await SaveSubscribersAsync(subscribers);
            return (true, "U çregjistruat me sukses.");
        }
        finally
        {
            Lock.Release();
        }
    }

    public static async Task<bool> RemoveByTokenAsync(string token)
    {
        await Lock.WaitAsync();
        try
        {
            var subscribers = await LoadSubscribersInternalAsync();
            var existing = subscribers.Find(s => s.Id == token && s.Active);
            if (existing == null) return false;

            var index = subscribers.IndexOf(existing);
            subscribers[index] = existing with { Active = false };
            await SaveSubscribersAsync(subscribers);
            return true;
        }
        finally
        {
            Lock.Release();
        }
    }

    public static async Task<bool> IsSubscribedAsync(string email)
    {
        var subscribers = await LoadSubscribersAsync();
        return subscribers.Any(s =>
            s.Email.Equals(email, StringComparison.OrdinalIgnoreCase) && s.Active);
    }

    public static async Task<List<Subscriber>> GetActiveSubscribersAsync()
    {
        var subscribers = await LoadSubscribersAsync();
        return subscribers.Where(s => s.Active).ToList();
    }

    // Internal loader without locking (caller must hold lock)
    private static async Task<List<Subscriber>> LoadSubscribersInternalAsync()
    {
        var path = GetFilePath();
        if (!File.Exists(path)) return [];
        try
        {
            var json = await File.ReadAllTextAsync(path);
            return JsonSerializer.Deserialize<List<Subscriber>>(json, ReadOptions) ?? [];
        }
        catch
        {
            return [];
        }
    }

    // Sent marker methods for the daily email service
    public static bool HasSentToday()
    {
        var path = GetSentMarkerPath();
        if (!File.Exists(path)) return false;
        var content = File.ReadAllText(path).Trim();
        return content == DateTime.Now.ToString("yyyy-MM-dd");
    }

    public static void MarkSentToday()
    {
        Directory.CreateDirectory(GetDataDirectory());
        File.WriteAllText(GetSentMarkerPath(), DateTime.Now.ToString("yyyy-MM-dd"));
    }
}
*/
