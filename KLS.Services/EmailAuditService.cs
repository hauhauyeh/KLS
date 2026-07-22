using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;

namespace KLS.Services
{
    /// <summary>
    /// Sends system emails and writes one audited EmailLog per send. The log is
    /// written on a fresh unit of work (via <see cref="IUnitOfWorkFactory"/>), not
    /// the request-scoped one, so the background continuation never touches a
    /// context shared with the request thread.
    /// </summary>
    public class EmailAuditService : IEmailAuditService
    {
        private readonly IEmailService _emailService;
        private readonly IEmailSettingService _emailSettingService;
        private readonly IUnitOfWorkFactory _uowFactory;

        public EmailAuditService(
            IEmailService emailService,
            IEmailSettingService emailSettingService,
            IUnitOfWorkFactory uowFactory)
        {
            _emailService = emailService;
            _emailSettingService = emailSettingService;
            _uowFactory = uowFactory;
        }

        public void SendAndLog(EmailAuditMessage message)
        {
            // Resolve settings on the calling (request) thread.
            var setting = _emailSettingService.GetSetting();

            // Empty recipient never leaves the app: record as not-sent, do not send.
            if (string.IsNullOrWhiteSpace(message.To))
            {
                WriteLog(message, setting, EmailAudit.DeliveryStatus.Unknown, "No recipient");
                return;
            }

            Task.Factory.StartNew(
                    () => _emailService.SendEmail(setting, message.To, message.Subject, message.HtmlBody, message.Attachments),
                    TaskCreationOptions.LongRunning)
                .ContinueWith(t =>
                {
                    var result = t.IsFaulted
                        ? (t.Exception?.GetBaseException().Message ?? "Send task failed")
                        : t.Result;

                    var status = string.IsNullOrEmpty(result)
                        ? EmailAudit.DeliveryStatus.Sent
                        : EmailAudit.DeliveryStatus.Failed;

                    WriteLog(message, setting, status, result);
                });
        }

        public string SendAndLogSync(EmailAuditMessage message)
        {
            var setting = _emailSettingService.GetSetting();

            if (string.IsNullOrWhiteSpace(message.To))
            {
                WriteLog(message, setting, EmailAudit.DeliveryStatus.Unknown, "No recipient");
                return "";
            }

            var result = _emailService.SendEmail(setting, message.To, message.Subject, message.HtmlBody, message.Attachments);

            var status = string.IsNullOrEmpty(result)
                ? EmailAudit.DeliveryStatus.Sent
                : EmailAudit.DeliveryStatus.Failed;

            WriteLog(message, setting, status, result);
            return result;
        }

        private void WriteLog(EmailAuditMessage m, EmailSetting? setting, string deliveryStatus, string? error)
        {
            try
            {
                var log = new EmailLog
                {
                    PayeeId = m.PayeeId,
                    Email = m.To,
                    SentDate = DateTime.UtcNow,
                    Status = deliveryStatus == EmailAudit.DeliveryStatus.Sent,
                    ErrorMessage = string.IsNullOrEmpty(error) ? null : error,
                    EmailCategory = m.EmailCategory,
                    EmailType = m.EmailType,
                    EventType = MapEventType(m.EmailType),
                    FromEmail = setting?.FromEmail,
                    DocumentType = m.DocumentType,
                    DocumentId = m.DocumentId,
                    DocumentNumber = m.DocumentNumber,
                    RelatedEntityType = m.RelatedEntityType,
                    RelatedEntityId = m.RelatedEntityId,
                    Subject = m.Subject,
                    RequestedBy = m.RequestedBy,
                    Source = m.Source,
                    Provider = DeriveProvider(setting?.Host),
                    DeliveryStatus = deliveryStatus
                };

                using var uow = _uowFactory.Create();
                uow.EmailLogs.Add(log);
                uow.Commit();
            }
            catch
            {
                // An audit-write failure must never break the email workflow, but
                // it must not crash the background thread either. Swallow here; the
                // send outcome is already returned to the caller in the sync path.
            }
        }

        /// <summary>
        /// Maps the normalized EmailType to a legacy EmailLogEvent value for
        /// backward compatibility; null when there is no legacy equivalent.
        /// </summary>
        private static string? MapEventType(string? emailType) => emailType switch
        {
            EmailAudit.EmailType.Invoice => EnumHelper.EmailLogEvent.Invoice.ToString(),
            EmailAudit.EmailType.Statement => EnumHelper.EmailLogEvent.Statement.ToString(),
            EmailAudit.EmailType.PriceSheet => EnumHelper.EmailLogEvent.PriceSheet.ToString(),
            EmailAudit.EmailType.ACHReceipt => EnumHelper.EmailLogEvent.ACHReceipt.ToString(),
            _ => null
        };

        private static string DeriveProvider(string? host)
        {
            if (string.IsNullOrWhiteSpace(host))
                return "SMTP";

            var h = host.ToLowerInvariant();
            if (h.Contains("gmail") || h.Contains("google"))
                return "Gmail";
            if (h.Contains("office365") || h.Contains("outlook") || h.Contains("microsoft"))
                return "Office365";

            return "SMTP";
        }
    }
}
