using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    /// <summary>
    /// Registration of a source document that Bank Feed itself created.
    /// BankFeedMatch links a bank row to a journal entry that already existed;
    /// this records the other case, where Bank Feed created the document and can undo it.
    /// </summary>
    public class BankFeedSource
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long BankFeedSourceId { get; set; }

        public long BankFeedTransactionId { get; set; }

        /// <summary>VendorPayment or CustomerPayment.</summary>
        public string SourceDocType { get; set; } = string.Empty;

        /// <summary>Polymorphic: a VendorPaymentId or a CustomerPaymentId, per SourceDocType.</summary>
        public long SourceDocId { get; set; }

        public long? TxId { get; set; }

        /// <summary>Which Bank Feed workflow created it, e.g. PayOpenBill.</summary>
        public string Mode { get; set; } = string.Empty;

        /// <summary>Active or Reversed.</summary>
        public string Status { get; set; } = string.Empty;

        /// <summary>Signed bank amount — negative for money out.</summary>
        public decimal OriginalBankAmount { get; set; }

        public decimal AppliedAmount { get; set; }

        public decimal DifferenceAmount { get; set; }

        public string? DifferenceResolution { get; set; }

        public int? DifferenceAccountId { get; set; }

        public string? DifferenceMemo { get; set; }

        public DateTime CreatedAt { get; set; }

        public int CreatedBy { get; set; }

        public DateTime? ReversedAt { get; set; }

        public int? ReversedBy { get; set; }

        public string? ReverseReason { get; set; }
    }
}
