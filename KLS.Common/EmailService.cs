using MailKit.Security;
using MimeKit;
using Razor.Templating.Core;
using MailKit.Net.Smtp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Common
{
    public interface IEmailService
    {
        string SendEmail(dynamic emailsetting, string to, string subject, string htmlbody, string[]? attachfiles = null);

        string RenderEmailTemplate(string template, object model);
    }

    public class EmailService
    {
        public static string SendEmail(dynamic emailsetting, string to, string subject, string htmlbody, string[]? attachfiles = null)
        {
            try
            {
                if (string.IsNullOrEmpty(to))
                    return "";

                string displayName = emailsetting.DisplayName;
                string from = emailsetting.FromEmail;
                string host = emailsetting.Host;
                string username = emailsetting.Username;
                string password = emailsetting.Password;
                int port = emailsetting.Port;

                // create message
                var email = new MimeMessage();
                email.Subject = subject;
                email.From.Add(new MailboxAddress(displayName, from));

                List<string> toemails = new();

                if (!string.IsNullOrEmpty(to))
                    toemails = to.Split(';').ToList();

                if (toemails.Count > 0)
                {
                    foreach (var toemail in toemails)
                        email.To.Add(MailboxAddress.Parse(toemail));
                }

                var builder = new BodyBuilder
                {
                    HtmlBody = htmlbody
                };

                //attach
                if (attachfiles != null)
                {
                    foreach (var file in attachfiles)
                        builder.Attachments.Add(file);
                }

                email.Body = builder.ToMessageBody();

                // send email
                using var smtp = new SmtpClient();
                smtp.Connect(host, port, SecureSocketOptions.StartTls);
                smtp.Authenticate(username, password);
                var result = smtp.Send(email);
                smtp.Disconnect(true);

                return "";
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
        }

        public static string RenderEmailTemplate(string templatePath, object model)
        {
            return RazorTemplateEngine.RenderAsync(templatePath, model).Result;
        }
    }
}
