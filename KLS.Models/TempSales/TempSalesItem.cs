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
    public class TempSalesItem
    {
        [Key]
        public int TempSalesId { get; set; }

        public int SalesId { get; set; }
        public int PayeeId { get; set; }

        public int? LineId { get; set; }
        public string? LineType { get; set; }

        public int? ItemId { get; set; }
        public int? AccountId { get; set; }
        public int? ItemUnitId { get; set; }
        public string? Unit { get; set; }

        public bool IsFree { get; set; }
        public bool IsOut { get; set; }
        public bool IsCRCG { get; set; }

        public decimal? OrdQty { get; set; }
        public decimal? ShipQty { get; set; }
        public decimal? BillQty { get; set; }


        public decimal? UnitPrice { get; set; }
        public string? Notes { get; set; }

        public bool IsTaxable { get; set; }

        public decimal? OrgPrice { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? DiscountPercent { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? FactorToBase { get; set; }

        public int? SourceTempSalesId { get; set; }

        public bool IsStrike { get; set; }

        public int? ParentTempSalesId { get; set; }
        public int? RootTempSalesId { get; set; }
        public string CartLineType { get; set; } = "MAIN";
        public bool IsSystemManaged { get; set; }
        public int? DisplaySort { get; set; }
        public int? SalesDetailId { get; set; }

        public decimal? ExtTotal => Utilities.Rounding((BillQty ?? 0m) * (UnitPrice ?? 0m), 2);

        public string? ItemName { get; set; }

        public string? ItemCode { get; set; }

        public string? PackSize { get; set; }

        public decimal? CaseWeight { get; set; }

        public decimal? CaseTotal
        {
            get
            {
                return LineType == EnumHelper.LineType.I.ToString() ? Utilities.Rounding(OrdQty / FactorToBase, 6) : 0;
            }
        }

        [NotMapped]
        public bool IsDefaultPrice { get; set; }

        [NotMapped]
        public bool IsUnitChange { get; set; }
    }
}
