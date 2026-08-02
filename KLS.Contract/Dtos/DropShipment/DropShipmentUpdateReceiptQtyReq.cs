namespace KLS.Contract.Dtos.DropShipment
{
    public class DropShipmentUpdateReceiptQtyReq
    {
        public DateOnly? ReceiptDate { get; set; }
        public string? ItemsJson { get; set; }
    }
}
