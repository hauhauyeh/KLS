using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemDefaultFreight
    {
        [Key]
        public int ItemId { get; set; }

        public int? PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public decimal? FreightRate { get; set; }

        public decimal? PaletteFactor { get; set; }
    }
}
