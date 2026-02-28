using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PromotionBogo
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int PromotionBogoId { get; set; }

        public int PromotionId { get; set; }

        public string? ConditionType { get; set; }

        public int? ConditionItemId { get; set; }

        public int? ConditionCategoryId { get; set; }

        public decimal? ConditionQty { get; set; }

        public decimal? ConditionMinAmount { get; set; }

        public string? RewardType { get; set; }

        public int? RewardItemId { get; set; }

        public int? RewardCategoryId { get; set; }

        public decimal? RewardQty { get; set; }

        public string? DiscountType { get; set; }

        public decimal? DiscountValue { get; set; }
    }
}
