using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class EmailLogDTO
    {
        [Key]
        public int EmailLogId { get; set; }

        public int? PayeeId { get; set; }

        public string? EventType { get; set; }

        public string? Email { get; set; }

        public DateTime? SentDate { get; set; }

        public bool Status { get; set; }

        public string? ErrorMessage { get; set; }

        public string? PayeeName { get; set; }

        // --- Audit columns (Phase 5; must match dbo.EmailLog_GetAllList SELECT) ---

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

        public string? DeliveryStatus { get; set; }
    }
}
