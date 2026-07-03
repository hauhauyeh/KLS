using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempBombSales
    {
        [Key]
        public int TempBombId { get; set; }
        public int EmpId { get; set; }
        public int SalesId { get; set; }
        public int PayeeId { get; set; }

        public int? ItemId { get; set; }
        public int? ItemUnitId { get; set; }
        // Unit is set only via ApplyUnit() so the unit name can never be changed without also
        // updating ItemUnitId + FactorToBase. (Mirrors the TempSales entity. A prior bomb path
        // set Unit + FactorToBase but not ItemUnitId, producing crossed SalesDetail rows.)
        public string? Unit { get; private set; }

        public bool IsFree { get; set; }
        public bool IsOut { get; set; }
        public bool IsCRCG { get; set; }

        public decimal? OrdQty { get; set; }
        public decimal? ShipQty { get; set; }
        public decimal? BillQty { get; set; }

        public decimal? UnitPrice { get; set; }
        public decimal? ExtTotal { get; set; }

        public string? Notes { get; set; }

        public bool IsTaxable { get; set; }
        public bool IsUserOverWrite { get; set; }

        public decimal? OrgPrice { get; set; }
        public decimal? DiscountPercent { get; set; }
        public decimal? FactorToBase { get; set; }
        public int? SalesDetailId { get; set; }

        public bool IsChanged { get; set; }

        // Set unit name, id, and factor together — they are one atomic fact about the line.
        // Changing any subset (e.g. Unit + FactorToBase but not ItemUnitId) desyncs the line so
        // its ItemUnitId points at one unit while Unit/Factor describe another.
        public void ApplyUnit(string? unit, int? itemUnitId, decimal? factorToBase)
        {
            Unit = unit;
            ItemUnitId = itemUnitId;
            FactorToBase = factorToBase;
        }
    }
}
