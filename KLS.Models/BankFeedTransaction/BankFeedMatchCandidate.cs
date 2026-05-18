using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class BankFeedMatchCandidate
    {
        [Key]
        public long TxDetailId { get; set; }

        public long TxId { get; set; }

        public DateOnly TxDate { get; set; }

        public string? SourceDocType { get; set; }

        public int? SourceDocNumber { get; set; }

        public decimal Amount { get; set; }

        public string? ReferenceId { get; set; }

        public string? PayeeName { get; set; }
    }
}
