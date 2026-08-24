namespace KLS.Models
{
    public class SalesDropShipRestrictedUpdateResult
    {
        public SalesList Sales { get; set; } = null!;

        public bool NeedsReprint { get; set; }

        public bool NeedsRevisedInvoiceEmail { get; set; }
    }
}
