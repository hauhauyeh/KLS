using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class SalesQuoteDetail
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int SalesQuoteDetailId { get; set; }
        public int SalesQuoteId { get; set; }
        public int LineId { get; set; }
        public int ItemId { get; set; }
        public int ItemUnitId { get; set; }
        public string? Unit { get; set; }
        public decimal? OrdQty { get; set; }
        public decimal? UnitPrice { get; set; }
        public decimal? ExtTotal { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? FactorToBase { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? BaseOrdQty { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? DiscountPercent { get; set; }
        public string? Notes { get; set; }
        public bool IsTaxable { get; set; }
    }
}
