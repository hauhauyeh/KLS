using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class ItemQuoteManagerUpdateDraftRowReq
    {
        [Column(TypeName = "decimal(18,4)")]
        public decimal? MarkupPercent { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? TargetPrice { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? NewPrice { get; set; }

        public bool IsFixed { get; set; }
    }
}
