using System.Collections.Generic;

namespace KLS.Models.Cart
{
    public class WebCartItem
    {
        public int TempSalesId { get; set; }
        public int? ItemId { get; set; }
        public string? ItemCode { get; set; }
        public string? ItemName { get; set; }
        public string? PrimaryImageUrl { get; set; }
        public int? ItemUnitId { get; set; }
        public string? Unit { get; set; }

        // Unit ratio: BaseQty = OrdQty * MultipleToBase / FactorToBase. FactorToBase is the
        // TempSales snapshot; MultipleToBase comes live from ItemUnit via TempSales_GetList.
        public decimal? FactorToBase { get; set; }
        public int MultipleToBase { get; set; } = 1;
        public decimal? OrdQty { get; set; }
        public decimal? UnitPrice { get; set; }
        public decimal? ExtTotal { get; set; }
        public decimal? LCloseQty { get; set; }

        public string? CartLineType { get; set; }
        public bool IsSystemManaged { get; set; }
        public decimal? OrgPrice { get; set; }
        public int? ParentTempSalesId { get; set; }
        public bool IsFree { get; set; }
        public string? Notes { get; set; }
        public int? PromotionId { get; set; }
    }
}
