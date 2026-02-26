using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PromotionList
    {
        [Key]
        public int PromotionId { get; set; }

        public string? Name { get; set; }

        public string? DisplayName { get; set; }

        public string? PromotionType { get; set; }

        public DateOnly? StartDate { get; set; }

        public DateOnly? EndDate { get; set; }

        public bool IsActive { get; set; }
    }
}
