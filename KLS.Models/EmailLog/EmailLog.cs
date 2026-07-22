using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class EmailLog
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int EmailLogId { get; set; }

        public int? PayeeId { get; set; }

        public string? EventType { get; set; }

        public string? Email { get; set; }

        public DateTime? SentDate { get; set; }

        public bool Status { get; set; }

        public string? ErrorMessage { get; set; }

        // --- Audit columns (added 2026-07-22, EmailLog system-wide audit) ---

        public string? EmailCategory { get; set; }

        public string? EmailType { get; set; }

        public string? FromEmail { get; set; }

        public string? DocumentType { get; set; }

        public int? DocumentId { get; set; }

        public string? DocumentNumber { get; set; }

        public string? RelatedEntityType { get; set; }

        public int? RelatedEntityId { get; set; }

        public string? Subject { get; set; }

        public int? RequestedBy { get; set; }

        public string? Source { get; set; }

        public string? Provider { get; set; }

        public string? ProviderMessageId { get; set; }

        public string? DeliveryStatus { get; set; }

        public DateTime? LastDeliveryEventAt { get; set; }
    }
}
