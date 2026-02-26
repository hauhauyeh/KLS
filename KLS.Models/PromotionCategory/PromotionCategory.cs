using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PromotionCategory
    {
        [Key]
        public int PromotionCategoryId { get; set; }

        public int PromotionId { get; set; }

        public int CategoryId { get; set; }
    }
}
