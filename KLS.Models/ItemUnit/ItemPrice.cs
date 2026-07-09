using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemPrice
    {
        [Key]
        public int ItemId { get; set; }

        public int ItemUnitId { get; set; }

        public string? DefaultUnit { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? DefaultPrice { get; set; }

        [Column(TypeName = "decimal(18, 6)")]
        public decimal FactorToBase { get; set; }

        public bool IsTaxable { get; set; }

        //public decimal? ListPrice { get; set; }

        //[Column(TypeName = "decimal(18, 4)")]
        //public decimal? Discount { get; set; }
    }
}
