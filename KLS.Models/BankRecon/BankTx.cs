namespace KLS.Models
{
    public class BankTx
    {
        public int AutoId { get; set; }

        public long? TxId { get; set; }

        public DateOnly? TxDate { get; set; }

        public string? SourceDocType { get; set; }

        public int? SourceDocNumber { get; set; }

        public decimal? Amount { get; set; }

        public bool? IsLocked { get; set; }

        public DateOnly? BankDate { get; set; }

        public string? PayeeName { get; set; }

        public string? ReferenceId { get; set; }

        public int? PayeeId { get; set; }

        public string? PaymentMethod { get; set; }
    }
}
