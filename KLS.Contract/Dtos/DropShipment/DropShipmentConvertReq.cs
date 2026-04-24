namespace KLS.Contract.Dtos.DropShipment
{
    public class DropShipmentConvertReq
    {
        public int PurchaseId { get; set; }
        public string? VendorDocNumber { get; set; }
        public DateTime? InvoiceDate { get; set; }
    }
}
