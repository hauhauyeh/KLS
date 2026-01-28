using KLS.Contract.Services;
using KLS.Models;
using MailKit.Security;
using MimeKit;
using Razor.Templating.Core;
using MailKit.Net.Smtp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class EmailService : IEmailService
    {
        public string SendEmail(EmailSetting setting, string to, string subject, string htmlbody, string[]? attachfiles = null)
        {
            try
            {
                if (string.IsNullOrEmpty(to))
                    return "";

                // create message
                var email = new MimeMessage
                {
                    Subject = subject
                };
                email.From.Add(new MailboxAddress(setting.DisplayName, setting.FromEmail));

                List<string> toemails = [];

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
                smtp.Connect(setting.Host, setting.Port, SecureSocketOptions.StartTls);
                smtp.Authenticate(setting.Username, setting.Password);
                var result = smtp.Send(email);
                smtp.Disconnect(true);

                return "";
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
        }

        public string RenderEmailTemplate(string templatePath, object model)
        {
            return RazorTemplateEngine.RenderAsync(templatePath, model).Result;
        }
    }
}
