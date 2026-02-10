using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempItemQuote
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TempQuoteId { get; set; }

        public int EmpId { get; set; }

        public int PayeeId { get; set; }

        public int ItemId { get; set; }

        public int ItemUnitId { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? MarkupPercent { get; set; }

        public decimal? TargetPrice { get; set; }

        public decimal? NewPrice { get; set; }

        public decimal? OldPrice { get; set; }

        public bool IsFixed { get; set; }
    }
}
