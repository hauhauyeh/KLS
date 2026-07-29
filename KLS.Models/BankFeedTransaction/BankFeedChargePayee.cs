namespace KLS.Models
{
    /// <summary>
    /// The payee a bank charge was last billed to, used to pre-fill the picker on the
    /// Create Vendor Payment modal.
    /// </summary>
    /// <remarks>
    /// Deliberately not the Payee entity: this is a two-field lookup and Payee carries 64
    /// columns of master data the caller has no use for.
    /// </remarks>
    public class BankFeedChargePayee
    {
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }
    }
}
