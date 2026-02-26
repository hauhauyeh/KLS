using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Promotion
    {
        public Promotion()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        public int PromotionId { get; set; }

        public string? Name { get; set; }

        public string? DisplayName { get; set; }

        public string? PromotionType { get; set; }

        public decimal? DiscountValue { get; set; }

        public decimal? MaxDiscountAmount { get; set; }

        public decimal? MinOrderAmount { get; set; }

        public DateOnly? StartDate { get; set; }

        public DateOnly? EndDate { get; set; }

        public bool IsActive { get; set; }

        public int MaxUsageGlobal { get; set; }

        public int MaxUsagePerUser { get; set; }

        public decimal? MaxDiscountPerUser { get; set; }

        public bool IsFirstOrderOnly { get; set; }

        public int? BogoMaxRewardRepeats { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public virtual ICollection<PromotionItem>? PromotionItems { get; set; }

        public virtual ICollection<PromotionCategory>? PromotionCategories { get; set; }

        public virtual ICollection<PromotionBogo>? PromotionBogos { get; set; }

        [NotMapped]
        public ICollection<int>? DeletedBogoIds { get; set; }
    }
}
