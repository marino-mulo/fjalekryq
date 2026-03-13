namespace LojraLogjike.Api.Email;

public class EmailSettings
{
    public string SmtpHost { get; set; } = "smtp.gmail.com";
    public int SmtpPort { get; set; } = 587;
    public string SenderEmail { get; set; } = "";
    public string SenderName { get; set; } = "Lojra Logjike";
    public string AppPassword { get; set; } = "";
    public string SiteUrl { get; set; } = "http://localhost:4200";
}
