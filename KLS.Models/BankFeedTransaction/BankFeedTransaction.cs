using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class BankFeedTransaction
    {
        public BankFeedTransaction()
        {
            ImportBatchId = Guid.NewGuid();
            Status = "Pending";
            ImportedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long BankFeedTransactionId { get; set; }

        public long BankFeedAccountId { get; set; }

        public Guid ImportBatchId { get; set; }

        public int RowNo { get; set; }

        public DateOnly PostedDate { get; set; }

        public decimal Amount { get; set; }

        public string Description { get; set; } = string.Empty;

        public string? ReferenceNo { get; set; }

        public string? CheckNumber { get; set; }

        public decimal? Balance { get; set; }

        public string Status { get; set; } = "Pending";

        public DateOnly? ClearedBankDate { get; set; }

        public DateTime? MatchedAt { get; set; }

        public int? MatchedBy { get; set; }

        public string? ExcludeReason { get; set; }

        public DateTime ImportedAt { get; set; }
    }
}
