using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class TempSalesQuoteItem
    {
        [Key]
        public int TempSalesQuoteId { get; set; }
        public int SalesQuoteId { get; set; }
        public int PayeeId { get; set; }
        public int? LineId { get; set; }
        public string? LineType { get; set; }
        public int? ItemId { get; set; }
        public int? AccountId { get; set; }
        public int? ItemUnitId { get; set; }
        public string? Unit { get; set; }
        public decimal? OrdQty { get; set; }
        public decimal? UnitPrice { get; set; }
        public string? Notes { get; set; }
        public bool IsTaxable { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? DiscountPercent { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? FactorToBase { get; set; }
        public bool IsStrike { get; set; }
        public string? ChangeStatus { get; set; }

        public decimal? ExtTotal => KLS.Common.Utilities.Rounding((OrdQty ?? 0m) * (UnitPrice ?? 0m), 2);

        public string? ItemName { get; set; }
        public string? ItemCode { get; set; }
        public string? PackSize { get; set; }
        public decimal? CaseWeight { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? LCloseQty { get; set; }
        public string? BaseUnit { get; set; }
        public decimal? ListPrice { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? Discount
        {
            get
            {
                return ListPrice.HasValue && ListPrice != 0 ?
                    KLS.Common.Utilities.Rounding((ListPrice - UnitPrice) / ListPrice, 4) : 0;
            }
        }

        [NotMapped]
        public bool IsUnitChange { get; set; }
    }
}
