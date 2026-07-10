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
    public class TempSales
    {
        public TempSales()
        {
            ChangeStatus = EnumHelper.ChangeStatus.I.ToString();
            LineType = EnumHelper.LineType.I.ToString();
            FactorToBase = 1;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TempSalesId { get; set; }

        public int EmpId { get; set; }
        public int SalesId { get; set; }
        public int PayeeId { get; set; }

        public int? LineId { get; set; }

        [Required]
        [MaxLength(1)]
        public string LineType { get; set; } = null!;

        public int? ItemId { get; set; }
        public int? AccountId { get; set; }

        public int? ItemUnitId { get; set; }

        [MaxLength(50)]
        public string? Unit { get; private set; }

        public bool IsFree { get; private set; }
        public bool IsOut { get; private set; }
        public bool IsCRCG { get; private set; }


        public decimal? OrdQty { get; private set; }
        public decimal? ShipQty { get; private set; }
        public decimal? BillQty { get; private set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? UnitPrice { get; set; }

        public decimal? ExtTotal => Utilities.Rounding((BillQty ?? 0m) * (UnitPrice ?? 0m), 2);

        [MaxLength(300)]
        public string? Notes { get; set; }

        public bool IsTaxable { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? OrgPrice { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? DiscountPercent { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? FactorToBase { get; set; }

        [MaxLength(1)]
        public string? ChangeStatus { get; set; }

        public int? SalesDetailId { get; set; }

        public int? ParentSalesNumber { get; set; }

        public int? SourceTempSalesId { get; set; }

        public bool IsStrike { get; set; }

        public int? ParentTempSalesId { get; set; }
        public int? RootTempSalesId { get; set; }
        public string CartLineType { get; set; } = "MAIN";
        public bool IsSystemManaged { get; set; }
        public int? DisplaySort { get; set; }

        private void ApplyFlagRules()
        {
            if (IsFree)
            {
                ShipQty = OrdQty;
                BillQty = 0;
            }
            else if (IsOut)
            {
                ShipQty = 0;
                BillQty = 0;
            }
            else if (IsCRCG)
            {
                ShipQty = 0;
                BillQty = OrdQty;
            }
            else
            {
                ShipQty = OrdQty;
                BillQty = OrdQty;
            }
        }

        public void ApplyEdits(decimal? ordQty, bool isFree, bool isOut, bool isCrcg, decimal? unitPrice, string? notes)
        {
            OrdQty = ordQty;
            IsFree = isFree;
            IsOut = isOut;
            IsCRCG = isCrcg;
            UnitPrice = unitPrice;
            Notes = notes;

            ApplyFlagRules();
        }

        public void ApplyUnit(string unit, int? itemUnitId, decimal? factorToBase)
        {
            Unit = unit;
            ItemUnitId = itemUnitId;
            FactorToBase = factorToBase;
        }
    }
}
