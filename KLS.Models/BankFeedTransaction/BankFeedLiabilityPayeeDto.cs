namespace KLS.Models
{
    /// <summary>
    /// One tax or loan liability payee offered by the Bank Feed liability-payment tab.
    /// Kind is 'Tax' or 'Loan', tagged by which manager list returned the row
    /// (LiabilityList carries no PayeeType). BalanceRemaining is display-only, never a gate.
    /// </summary>
    public record BankFeedLiabilityPayeeDto(int PayeeId, string? PayeeName, decimal? BalanceRemaining, string Kind);
}
