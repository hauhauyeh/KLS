namespace KLS.Models
{
    /// <summary>
    /// Create an Other Incoming Payment from a pending money-in bank feed row and match the row to it.
    /// </summary>
    public class BankFeedCreateRuleMoneyInReq
    {
        public long BankFeedTransactionId { get; set; }

        /// <summary>Optional. The SQL path uses the system fallback payee when this is empty.</summary>
        public int? PayeeId { get; set; }

        public int AccountId { get; set; }

        public string? ReferenceId { get; set; }

        public string? Notes { get; set; }

        public bool AppendBankDescription { get; set; } = true;
    }
}
