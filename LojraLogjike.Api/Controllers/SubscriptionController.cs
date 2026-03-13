using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;
using LojraLogjike.Api.Email;
using Microsoft.AspNetCore.Mvc;

namespace LojraLogjike.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SubscriptionController : ControllerBase
{
    private static readonly Regex EmailRegex = new(
        @"^[^@\s]+@[^@\s]+\.[^@\s]+$",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    /// <summary>
    /// Subscribe an email for daily puzzle reminders.
    /// </summary>
    [HttpPost("subscribe")]
    public async Task<IActionResult> Subscribe([FromBody] SubscribeRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.Email))
            return BadRequest(new { success = false, message = "Email-i është i detyrueshëm." });

        if (!EmailRegex.IsMatch(request.Email.Trim()))
            return BadRequest(new { success = false, message = "Formati i email-it nuk është i vlefshëm." });

        var (success, message) = await SubscriberStore.AddSubscriberAsync(request.Email.Trim());
        return Ok(new { success, message });
    }

    /// <summary>
    /// Unsubscribe an email from daily puzzle reminders.
    /// </summary>
    [HttpPost("unsubscribe")]
    public async Task<IActionResult> Unsubscribe([FromBody] UnsubscribeRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.Email))
            return BadRequest(new { success = false, message = "Email-i është i detyrueshëm." });

        var (success, message) = await SubscriberStore.RemoveSubscriberAsync(request.Email.Trim());
        return Ok(new { success, message });
    }

    /// <summary>
    /// Check if an email is currently subscribed.
    /// </summary>
    [HttpGet("status/{email}")]
    public async Task<IActionResult> GetStatus(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return BadRequest(new { subscribed = false });

        var subscribed = await SubscriberStore.IsSubscribedAsync(email.Trim());
        return Ok(new { subscribed });
    }

    /// <summary>
    /// Unsubscribe via token link from email (returns an HTML confirmation page).
    /// </summary>
    [HttpGet("unsubscribe/{token}")]
    public async Task<IActionResult> UnsubscribeByToken(string token)
    {
        var success = await SubscriberStore.RemoveByTokenAsync(token);

        var html = success
            ? @"<!DOCTYPE html><html lang=""sq""><head><meta charset=""UTF-8""><title>Çregjistrimi</title>
                <style>body{font-family:sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;background:#FFF8F0;margin:0;}
                .card{background:#fff;border:2px solid #1a1a1a;border-radius:16px;padding:40px;text-align:center;box-shadow:6px 6px 0 #1a1a1a;max-width:400px;}
                h2{margin:0 0 12px;font-size:1.5rem;}p{color:#666;margin:0 0 20px;}</style></head>
                <body><div class=""card""><h2>U çregjistruat me sukses!</h2><p>Nuk do të merrni më njoftime me email nga Lojra Logjike.</p></div></body></html>"
            : @"<!DOCTYPE html><html lang=""sq""><head><meta charset=""UTF-8""><title>Çregjistrimi</title>
                <style>body{font-family:sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;background:#FFF8F0;margin:0;}
                .card{background:#fff;border:2px solid #1a1a1a;border-radius:16px;padding:40px;text-align:center;box-shadow:6px 6px 0 #1a1a1a;max-width:400px;}
                h2{margin:0 0 12px;font-size:1.5rem;}p{color:#666;margin:0 0 20px;}</style></head>
                <body><div class=""card""><h2>Linku nuk është i vlefshëm</h2><p>Ky link çregjistrimi nuk është i vlefshëm ose tashmë është përdorur.</p></div></body></html>";

        return Content(html, "text/html");
    }
}

public record SubscribeRequest(string Email);
public record UnsubscribeRequest(string Email);
