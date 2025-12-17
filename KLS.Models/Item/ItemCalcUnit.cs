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
        public string? Unit { get; set; }

        public decimal? FactorToBase { get; set; }

        public bool IsBaseUnit { get; set; }

        public bool IsDefaultSalesUnit { get; set; }
    }
}
