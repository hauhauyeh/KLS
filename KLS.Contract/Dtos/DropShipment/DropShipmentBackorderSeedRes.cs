namespace KLS.Contract.Dtos.DropShipment
{
    public class DropShipmentBackorderSeedRes
    {
        public int SourceSalesId { get; set; }
        public int PayeeId { get; set; }
        public int VendorPayeeId { get; set; }
        public string? VendorName { get; set; }
        public string? CustPONumber { get; set; }
        public string? FactorPO { get; set; }
        public int GeneratedLineCount { get; set; }
        public string? Message { get; set; }
    }
}
