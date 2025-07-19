using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Term
    {
        public int TermId { get; set; }

        public string TermName { get; set; }

        public string? TermType { get; set; }

        public int? DueDays { get; set; }

        public int? DayOfMonth { get; set; }

        public decimal? Discount { get; set; }

        public bool IsInactive { get; set; }

        public string? Notes { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
