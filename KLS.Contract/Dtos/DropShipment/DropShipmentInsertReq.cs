namespace KLS.Contract.Dtos.DropShipment
{
    public class DropShipmentInsertReq
    {
        public int SalesId { get; set; }
        public int PayeeId { get; set; }
        public int VendorPayeeId { get; set; }
        public DateTime? ShipDate { get; set; }
        public string? ShipRoute { get; set; }
        public string? Instruction { get; set; }
        public DateTime? PurchaseDate { get; set; }
        public string? FactorPO { get; set; }
        public string? CustPONumber { get; set; }
        public bool IsBackorderDropShip { get; set; }
        public int? SourceSalesId { get; set; }
    }
}
