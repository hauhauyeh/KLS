using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System.Net;
using System.Text;

namespace KLS.Services
{
    public class ContactService : BaseService, IContactService
    {
        private readonly IEmailAuditService _emailAuditService;
        private readonly IEmailSettingService _emailSettingService;

        public ContactService(
            IUnitOfWork uow,
            IEmailAuditService emailAuditService,
            IEmailSettingService emailSettingService) : base(uow)
        {
            _emailAuditService = emailAuditService;
            _emailSettingService = emailSettingService;
        }

        public void SendMessage(ContactMessageReq req)
        {
            if (string.IsNullOrWhiteSpace(req.Name))
                throw new Exception("Full name is required.");

            if (string.IsNullOrWhiteSpace(req.Email))
                throw new Exception("Email is required.");

            if (string.IsNullOrWhiteSpace(req.Subject))
                throw new Exception("Subject is required.");

            if (string.IsNullOrWhiteSpace(req.Message))
                throw new Exception("Message is required.");

            var setting = _emailSettingService.GetSetting()
                ?? throw new Exception("Email settings are not configured.");

            var toEmail = string.IsNullOrWhiteSpace(setting.AdminEmail)
                ? "sales@klsfoods.com"
                : setting.AdminEmail;

            var subject = $"Website Contact: {req.Subject.Trim()}";

            var body = new StringBuilder()
                .AppendLine("<h2>New Contact Message</h2>")
                .AppendLine("<table cellpadding=\"6\" cellspacing=\"0\" border=\"0\">")
                .AppendLine($"<tr><td><strong>Name</strong></td><td>{Encode(req.Name)}</td></tr>")
                .AppendLine($"<tr><td><strong>Email</strong></td><td>{Encode(req.Email)}</td></tr>")
                .AppendLine($"<tr><td><strong>Phone</strong></td><td>{Encode(req.Phone)}</td></tr>")
                .AppendLine($"<tr><td><strong>Subject</strong></td><td>{Encode(req.Subject)}</td></tr>")
                .AppendLine("</table>")
                .AppendLine("<p><strong>Message</strong></p>")
                .AppendLine($"<div>{EncodeMultiline(req.Message)}</div>")
                .ToString();

            var result = _emailAuditService.SendAndLogSync(new EmailAuditMessage
            {
                To = toEmail,
                Subject = subject,
                HtmlBody = body,
                EmailCategory = EmailAudit.Category.Website,
                EmailType = EmailAudit.EmailType.ContactMessage,
                Source = EmailAudit.Source.System
            });

            if (!string.IsNullOrWhiteSpace(result))
                throw new Exception(result);
        }

        private static string Encode(string? value)
        {
            return WebUtility.HtmlEncode(value ?? string.Empty);
        }

        private static string EncodeMultiline(string? value)
        {
            return Encode(value).Replace("\r\n", "<br>").Replace("\n", "<br>");
        }
    }
}
