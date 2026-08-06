namespace KLS.Models
{
    /// <summary>
    /// One candidate undeposited customer payment for a pending money-in bank feed row.
    /// Projected from BankFeed_GetUndepositedPayments. A deposit always takes the payment's
    /// full PaymentAmount, so there is no apply/suggested amount here.
    /// </summary>
    public class BankFeedUndepositedPayment
    {
        public int CustomerPaymentId { get; set; }

        public int PaymentNumber { get; set; }

        public int PayeeId { get; set; }

        public string? CustomerName { get; set; }

        public DateOnly PaymentDate { get; set; }

        public string? PaymentType { get; set; }

        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public decimal PaymentAmount { get; set; }
    }
}
