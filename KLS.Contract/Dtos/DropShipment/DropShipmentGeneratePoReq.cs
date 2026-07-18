namespace KLS.Contract.Dtos.DropShipment
{
    public class DropShipmentGeneratePoReq
    {
        public int SalesId { get; set; }
        public int VendorPayeeId { get; set; }
        public DateTime? ArrivalDate { get; set; }
        public string? FactorPO { get; set; }
    }
}
