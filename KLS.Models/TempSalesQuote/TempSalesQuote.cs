using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class TempSalesQuote
    {
        public TempSalesQuote()
        {
            ChangeStatus = "I";
            FactorToBase = 1;
            LineType = "I";
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TempSalesQuoteId { get; set; }
        public int EmpId { get; set; }
        public int SalesQuoteId { get; set; }
        public int PayeeId { get; set; }
        public int? LineId { get; set; }

        [MaxLength(2)]
        public string LineType { get; set; }
        public int? ItemId { get; set; }
        public int? AccountId { get; set; }
        public int? ItemUnitId { get; set; }

        [MaxLength(50)]
        public string? Unit { get; set; }
        public decimal? OrdQty { get; set; }
        public decimal? UnitPrice { get; set; }
        public decimal? ExtTotal => KLS.Common.Utilities.Rounding((OrdQty ?? 0m) * (UnitPrice ?? 0m), 2);

        [Column(TypeName = "decimal(18,4)")]
        public decimal? DiscountPercent { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? FactorToBase { get; set; }

        [MaxLength(300)]
        public string? Notes { get; set; }
        public bool IsTaxable { get; set; } = true;

        [MaxLength(20)]
        public string? ChangeStatus { get; set; }
        public bool IsStrike { get; set; }
    }
}
