namespace KLS.Models
{
    /// <summary>
    /// Input to the audited email helper: what to send plus the audit metadata to
    /// log. Callers capture request-thread state (RequestedBy, Source) and pass it
    /// here as values before the send task starts.
    /// </summary>
    public class EmailAuditMessage
    {
        // --- Send ---
        public string? To { get; set; }

        public string? Subject { get; set; }

        public string? HtmlBody { get; set; }

        public string[]? Attachments { get; set; }

        // --- Audit metadata ---
        public string? EmailCategory { get; set; }

        public string? EmailType { get; set; }

        public int? PayeeId { get; set; }

        public string? DocumentType { get; set; }

        public int? DocumentId { get; set; }

        public string? DocumentNumber { get; set; }

        public string? RelatedEntityType { get; set; }

        public int? RelatedEntityId { get; set; }

        public int? RequestedBy { get; set; }

        public string? Source { get; set; }
    }
}
