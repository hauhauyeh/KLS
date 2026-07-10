using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemQuote
    {
        public ItemQuote()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int ItemQuoteId { get; set; }

        public int PayeeId { get; set; }

        public int ItemId { get; set; }

        public int ItemUnitId { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? MarkupPercent { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? TargetPrice { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? NewPrice { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? OldPrice { get; set; }

        public bool IsFixed { get; set; }

        public bool Inactive { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
