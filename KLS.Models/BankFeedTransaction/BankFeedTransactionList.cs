using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class BankFeedTransactionList
    {
        [Key]
        public long BankFeedTransactionId { get; set; }

        public long BankFeedAccountId { get; set; }

        public int AccountId { get; set; }

        public string? AccountName { get; set; }

        public Guid ImportBatchId { get; set; }

        public int RowNo { get; set; }

        public DateOnly PostedDate { get; set; }

        public decimal Amount { get; set; }

        public string Description { get; set; } = string.Empty;

        public string? ReferenceNo { get; set; }

        public string? CheckNumber { get; set; }

        public decimal? Balance { get; set; }

        public string Status { get; set; } = string.Empty;

        public DateOnly? ClearedBankDate { get; set; }

        public int MatchCount { get; set; }

        public string? MatchPayeeName { get; set; }

        public DateOnly? MatchTxDate { get; set; }

        public decimal? MatchAmount { get; set; }

        public string? MatchReferenceId { get; set; }

        public string? MatchSourceDocType { get; set; }

        public long? MatchCandidateTxId { get; set; }

        public long? MatchCandidateTxDetailId { get; set; }
    }
}
