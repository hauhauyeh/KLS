using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemCalcUnit
    {
        [Key]
        public string? WholeUnit { get; set; }

        public string? PackSize { get; set; }

        public string? RetailUnit { get; set; }

        public decimal? RetailFactor { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? RetailProfitPercent { get; set; }

        public decimal? RetailPrice { get; set; }
    }
}
