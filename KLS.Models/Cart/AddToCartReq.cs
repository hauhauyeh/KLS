namespace KLS.Models.Cart
{
    public class AddToCartReq
    {
        public int ItemId { get; set; }

        public decimal Qty { get; set; }

        public int? ItemUnitId { get; set; }

        public string? Unit { get; set; }
    }
}
