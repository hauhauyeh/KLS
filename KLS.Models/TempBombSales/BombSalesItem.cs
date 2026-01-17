using KLS.Common;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class BombSalesItem
    {
        [Key]
        public int TempBombId { get; set; }
        public int SalesId { get; set; }
        public int PayeeId { get; set; }

        public int? ItemId { get; set; }
        public int? ItemUnitId { get; set; }
        public string? Unit { get; set; }

        public bool IsFree { get; set; }
        public bool IsOut { get; set; }
        public bool IsCRCG { get; set; }

        public decimal? OrdQty { get; set; }
        public decimal? ShipQty { get; set; }
        public decimal? BillQty { get; set; }

        public decimal? UnitPrice { get; set; }
        public decimal? ExtTotal => Utilities.Rounding((BillQty ?? 0m) * (UnitPrice ?? 0m), 2);

        public string? Notes { get; set; }

        public bool IsTaxable { get; set; }
        public bool IsUserOverWrite { get; set; }

        public decimal? OrgPrice { get; set; }
        public decimal? DiscountPercent { get; set; }
        public decimal? FactorToBase { get; set; } 
        public int? SalesDetailId { get; set; }

        public bool IsChanged { get; set; }

        public string? PayeeName { get; set; }
        public string? ItemName { get; set; }
        public string? ItemCode { get; set; }

        public DateOnly? ShipDate { get; set; }
        public string? ShipRoute { get; set; }
        public string? LoadRoute { get; set; }

        public decimal? OrdCases => Utilities.Rounding(OrdQty / FactorToBase, 6);


        [NotMapped]
        public bool IsDefaultPrice { get; set; }
    }
}
