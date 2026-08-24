namespace KLS.Models
{
    /// <summary>
    /// Create a transfer from a pending bank feed row and match the row to it.
    /// </summary>
    public class BankFeedCreateTransferReq
    {
        public long BankFeedTransactionId { get; set; }

        public int TargetAccountId { get; set; }

        public string? ReferenceId { get; set; }

        public string? Notes { get; set; }

        public bool AppendBankDescription { get; set; } = true;
    }
}
