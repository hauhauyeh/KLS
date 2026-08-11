namespace KLS.Models
{
    public class SalesQuoteConvertToDropShipReq
    {
        public int VendorPayeeId { get; set; }
        public DateOnly? ShipDate { get; set; }
        public string? FactorPO { get; set; }
        public string? CustPONumber { get; set; }
    }
}
