using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models.TempSalesPromo
{
    public class TempSalesPromo
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TempSalesPromoId { get; set; }
        public int OwnerTempSalesId { get; set; }
        public int PromoTempSalesId { get; set; }
        public int PromotionId { get; set; }
        public int PromotionBogoId { get; set; }
    }
}
