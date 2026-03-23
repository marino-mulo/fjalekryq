// TODO: Uncomment when email subscription is needed
/*
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace Fjalekryq.Api.Email;

/// <summary>
/// Background service that sends daily reminder emails at 10:00 AM.
/// Checks every 60 seconds and uses a file marker to avoid duplicate sends.
/// </summary>
public class DailyEmailHostedService : BackgroundService
{
    private readonly ILogger<DailyEmailHostedService> _logger;
    private readonly IConfiguration _configuration;
    private static readonly TimeSpan CheckInterval = TimeSpan.FromSeconds(60);

    public DailyEmailHostedService(ILogger<DailyEmailHostedService> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Small delay on startup to let the web server initialize
        await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var now = DateTime.Now;
                if (now.Hour == 10 && now.Minute == 0 && !SubscriberStore.HasSentToday())
                {
                    await SendDailyEmails();
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error sending daily reminder emails");
            }

            await Task.Delay(CheckInterval, stoppingToken);
        }
    }

    private async Task SendDailyEmails()
    {
        var settings = new EmailSettings();
        _configuration.GetSection("EmailSettings").Bind(settings);

        if (string.IsNullOrEmpty(settings.SenderEmail) || string.IsNullOrEmpty(settings.AppPassword))
        {
            _logger.LogWarning("Email settings not configured (SenderEmail or AppPassword missing). Skipping daily emails.");
            SubscriberStore.MarkSentToday();
            return;
        }

        var subscribers = await SubscriberStore.GetActiveSubscribersAsync();
        if (subscribers.Count == 0)
        {
            _logger.LogInformation("No active subscribers. Skipping daily emails.");
            SubscriberStore.MarkSentToday();
            return;
        }

        _logger.LogInformation("Sending daily reminder emails to {Count} subscribers...", subscribers.Count);

        var sent = 0;
        var failed = 0;

        foreach (var subscriber in subscribers)
        {
            try
            {
                var unsubscribeUrl = $"{settings.SiteUrl.TrimEnd('/')}/api/subscription/unsubscribe/{subscriber.Id}";
                var htmlBody = EmailTemplate.BuildDailyEmail(settings.SiteUrl, unsubscribeUrl);

                var message = new MimeMessage();
                message.From.Add(new MailboxAddress(settings.SenderName, settings.SenderEmail));
                message.To.Add(MailboxAddress.Parse(subscriber.Email));
                message.Subject = "Enigmat e ditës janë gati! - Fjalekryq";

                var bodyBuilder = new BodyBuilder
                {
                    HtmlBody = htmlBody,
                    TextBody = $"Enigmat e sotme janë gati! Luaj tani: {settings.SiteUrl}"
                };
                message.Body = bodyBuilder.ToMessageBody();

                using var smtp = new SmtpClient();
                await smtp.ConnectAsync(settings.SmtpHost, settings.SmtpPort, SecureSocketOptions.StartTls);
                await smtp.AuthenticateAsync(settings.SenderEmail, settings.AppPassword);
                await smtp.SendAsync(message);
                await smtp.DisconnectAsync(true);

                sent++;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send email to {Email}", subscriber.Email);
                failed++;
            }
        }

        SubscriberStore.MarkSentToday();
        _logger.LogInformation("Daily emails sent: {Sent} success, {Failed} failed", sent, failed);
    }
}
*/
