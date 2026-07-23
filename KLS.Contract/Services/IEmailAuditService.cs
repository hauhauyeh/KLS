using KLS.Models;

namespace KLS.Contract.Services
{
    /// <summary>
    /// The required path for sending system emails: sends through the email
    /// service and writes exactly one audited EmailLog. Direct
    /// <c>IEmailService.SendEmail</c> use is deprecated outside this helper.
    /// </summary>
    public interface IEmailAuditService
    {
        /// <summary>
        /// Fire-and-forget: sends on a background task and logs after completion.
        /// Returns immediately. Use for the normal async senders.
        /// </summary>
        void SendAndLog(EmailAuditMessage message);

        /// <summary>
        /// Synchronous: sends inline, writes the log, and returns the provider
        /// result (empty string on success, error text on failure) so the caller
        /// can surface failures (e.g. the website contact form).
        /// </summary>
        string SendAndLogSync(EmailAuditMessage message);
    }
}
