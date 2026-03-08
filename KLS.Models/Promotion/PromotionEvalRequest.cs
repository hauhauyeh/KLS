namespace KLS.Models
{
    public class PromotionEvalRequest
    {
        public int EmpId { get; set; }
        public int SalesId { get; set; }
        public int PayeeId { get; set; }
        public int? UserId { get; set; }
        public string? CartSource { get; set; }

        /// <summary>
        /// Per-item promo toggles (TempSalesId + PromotionId pairs)
        /// </summary>
        public List<PromoToggle>? EnabledPromos { get; set; }
    }

    public class PromoToggle
    {
        public int TempSalesId { get; set; }
        public int PromotionId { get; set; }
    }
}
