namespace LojraLogjike.Api.Email;

/// <summary>
/// Builds branded HTML email content in Albanian for the daily puzzle reminder.
/// </summary>
public static class EmailTemplate
{
    public static string BuildDailyEmail(string siteUrl, string unsubscribeUrl)
    {
        return $@"<!DOCTYPE html>
<html lang=""sq"">
<head>
  <meta charset=""UTF-8"">
  <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
</head>
<body style=""margin:0; padding:0; background-color:#FFF8F0; font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;"">
  <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" style=""background-color:#FFF8F0; padding:32px 16px;"">
    <tr>
      <td align=""center"">
        <table role=""presentation"" width=""480"" cellpadding=""0"" cellspacing=""0"" style=""background-color:#ffffff; border:2px solid #1a1a1a; border-radius:16px; box-shadow:6px 6px 0px #1a1a1a; overflow:hidden;"">
          <!-- Header -->
          <tr>
            <td style=""background-color:#F59E0B; padding:28px 32px; text-align:center; border-bottom:2px solid #1a1a1a;"">
              <h1 style=""margin:0; font-size:26px; font-weight:900; color:#1a1a1a; letter-spacing:-0.5px;"">
                Lojra Logjike
              </h1>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style=""padding:32px 32px 24px;"">
              <h2 style=""margin:0 0 12px; font-size:20px; font-weight:800; color:#1a1a1a;"">
                Enigmat e sotme jan&#235; gati! &#127918;
              </h2>
              <p style=""margin:0 0 24px; font-size:15px; color:#444; line-height:1.6;"">
                Sfido veten me 6 loj&#235;ra t&#235; reja logjike. Sa shpejt mund t'i zgjidhni t&#235; gjitha?
              </p>

              <!-- Games List -->
              <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"" style=""margin-bottom:24px;"">
                <tr>
                  <td style=""padding:8px 0;"">
                    <span style=""display:inline-block; width:10px; height:10px; background:#A855F7; border-radius:50%; margin-right:10px; vertical-align:middle;""></span>
                    <span style=""font-size:14px; font-weight:700; color:#1a1a1a; vertical-align:middle;"">Zip</span>
                    <span style=""font-size:13px; color:#888; vertical-align:middle;""> &#8212; Gjej rrug&#235;n</span>
                  </td>
                </tr>
                <tr>
                  <td style=""padding:8px 0;"">
                    <span style=""display:inline-block; width:10px; height:10px; background:#F59E0B; border-radius:50%; margin-right:10px; vertical-align:middle;""></span>
                    <span style=""font-size:14px; font-weight:700; color:#1a1a1a; vertical-align:middle;"">Stars</span>
                    <span style=""font-size:13px; color:#888; vertical-align:middle;""> &#8212; Vendos yjet</span>
                  </td>
                </tr>
                <tr>
                  <td style=""padding:8px 0;"">
                    <span style=""display:inline-block; width:10px; height:10px; background:#E11D48; border-radius:50%; margin-right:10px; vertical-align:middle;""></span>
                    <span style=""font-size:14px; font-weight:700; color:#1a1a1a; vertical-align:middle;"">Queens</span>
                    <span style=""font-size:13px; color:#888; vertical-align:middle;""> &#8212; Vendos mbret&#235;reshat</span>
                  </td>
                </tr>
                <tr>
                  <td style=""padding:8px 0;"">
                    <span style=""display:inline-block; width:10px; height:10px; background:#F97316; border-radius:50%; margin-right:10px; vertical-align:middle;""></span>
                    <span style=""font-size:14px; font-weight:700; color:#1a1a1a; vertical-align:middle;"">Tango</span>
                    <span style=""font-size:13px; color:#888; vertical-align:middle;""> &#8212; Plotëso rrjetin</span>
                  </td>
                </tr>
                <tr>
                  <td style=""padding:8px 0;"">
                    <span style=""display:inline-block; width:10px; height:10px; background:#22C55E; border-radius:50%; margin-right:10px; vertical-align:middle;""></span>
                    <span style=""font-size:14px; font-weight:700; color:#1a1a1a; vertical-align:middle;"">Fjal&#235;kryq</span>
                    <span style=""font-size:13px; color:#888; vertical-align:middle;""> &#8212; Gjej fjal&#235;t</span>
                  </td>
                </tr>
                <tr>
                  <td style=""padding:8px 0;"">
                    <span style=""display:inline-block; width:10px; height:10px; background:#14B8A6; border-radius:50%; margin-right:10px; vertical-align:middle;""></span>
                    <span style=""font-size:14px; font-weight:700; color:#1a1a1a; vertical-align:middle;"">Gjarp&#235;ri</span>
                    <span style=""font-size:13px; color:#888; vertical-align:middle;""> &#8212; Ndiq shtegun</span>
                  </td>
                </tr>
              </table>

              <!-- CTA Button -->
              <table role=""presentation"" width=""100%"" cellpadding=""0"" cellspacing=""0"">
                <tr>
                  <td align=""center"">
                    <a href=""{siteUrl}"" target=""_blank""
                       style=""display:inline-block; background-color:#FEF3C7; color:#1a1a1a; font-size:15px; font-weight:800; text-decoration:none; padding:14px 40px; border:2px solid #1a1a1a; border-radius:10px; box-shadow:3px 3px 0px #1a1a1a;"">
                      Luaj Tani &#8594;
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style=""padding:20px 32px; border-top:1px solid #eee; text-align:center;"">
              <p style=""margin:0; font-size:12px; color:#999; line-height:1.5;"">
                Po e merr k&#235;t&#235; email sepse je abonuar n&#235; njoftimet e Lojra Logjike.
                <br/>
                <a href=""{unsubscribeUrl}"" style=""color:#999; text-decoration:underline;"">&#199;regjistrohu</a>
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>";
    }
}
