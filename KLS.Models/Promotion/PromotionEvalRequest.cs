namespace KLS.Models.PromotionEval
{
    public class PromotionEvalRequest
    {
        public int SalesId { get; set; }
        public int PayeeId { get; set; }
    }

    public class PromoToggleRequest
    {
        public int SalesId { get; set; }
        public int PayeeId { get; set; }
        public int OwnerTempSalesId { get; set; }
        public int PromotionId { get; set; }
        public int PromotionBogoId { get; set; }
        public bool Enable { get; set; }
    }
}
