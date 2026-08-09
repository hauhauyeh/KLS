namespace KLS.Contract.Dtos.DropShipment
{
    public class DropShipmentConvertReq
    {
        public int PurchaseId { get; set; }
        public string? VendorDocNumber { get; set; }
        public string? ContainerNumber { get; set; }
    }
}
