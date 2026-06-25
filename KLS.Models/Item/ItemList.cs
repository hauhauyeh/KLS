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
    public class ItemList
    {
        [Key]
        public int ItemId { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? ItemName2 { get; set; }

        public string? SetPacking { get; set; }

        //public string? DefaultUnit { get; set; }

        //public string? WholeUnit { get; set; }

        public DateOnly? LastCostDate { get; set; }

        //public decimal? RecentCost { get; set; }

        //public decimal? RecentCostB4 { get; set; }

        //public int? CostIntervalDays { get; set; }

        //public decimal? DefaultCost { get; set; }


        //public decimal? P1 { get; set; }

        //public decimal? RetailPrice { get; set; }

        //[Column(TypeName = "decimal(18, 4)")]
        //public decimal? RetailProfitPercent { get; set; }

        //public decimal? RetailFactor { get; set; }

        public int? ItemUnitId { get; set; }

        public string? BaseUnit { get; set; }

        public decimal? BaseRecentCost { get; set; }

        // 2026-06-25: recent-cost breakdown surfaced from the View_RecentCost pivot
        // (BaseRecentCost = BaseGoodsCost + BaseLandingCost; landing is 0 when none).
        public decimal? BaseGoodsCost { get; set; }

        public decimal? BaseLandingCost { get; set; }

        // 2026-05-11: cost-trend restore. SP fills these from a pivot of
        // View_RecentCost (RN=1 vs RN=2). Naming parallels BaseRecentCost --
        // "Base" prefix marks per-base-unit values. TotalCost in the view
        // is (BaseCost + LandedCostPerCase) = goods + landing per case, so
        // the trend reflects movement in the all-in landed cost.
        public decimal? BaseRecentCostB4 { get; set; }

        public int? CostIntervalDays { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? BaseCostTrendPercent
        {
            get
            {
                if (!BaseRecentCost.HasValue || !BaseRecentCostB4.HasValue)
                    return null;

                if (BaseRecentCostB4.Value == 0)
                    return null;

                return Utilities.Rounding(
                    (BaseRecentCost.Value - BaseRecentCostB4.Value) / BaseRecentCostB4.Value,
                    4
                );
            }
        }

        public decimal? BaseP1 { get; set; }

        [NotMapped]
        public int? AltItemUnitId { get; set; }

        [NotMapped]
        public string? AltUnit { get; set; }

        [NotMapped]
        public decimal? AltFactorToBase { get; set; }

        [NotMapped]
        public decimal? AltPricePercentToBase { get; set; }

        [NotMapped]
        public decimal? AltP1 { get; set; }

        public decimal? SaftyInventory { get; set; }

        public int? PreferredVendorId { get; set; }

        public string? VendorName { get; set; }

        public bool IsHighlighted { get; set; }

        public bool Inactive { get; set; }

        // IsDeleted projection removed 2026-05-08 (forward-removal of D toggle).
        // Item_GetAllList no longer projects i.IsDeleted, so the DTO must
        // not carry this column either or EF will throw on materialization.
        // The page list's row-dim binding now uses i.Inactive only.
        // The core entity Item.cs still has IsDeleted -- that's the real
        // soft-delete column, untouched.
        // public bool IsDeleted { get; set; }

        public DateOnly? ExpiryDate { get; set; }

        public decimal? LCloseQty { get; set; }

        public decimal? LAvgCost { get; set; }

        public decimal? LInventoryValue { get; set; }

        public decimal? CaseWeight { get; set; }

        public decimal? Last3M { get; set; }

        public decimal? M0 { get; set; }

        public decimal? M1 { get; set; }

        public decimal? M2 { get; set; }

        public decimal? M3 { get; set; }

        public decimal? YTD { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? YTDSalesPercent { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? RecentCostPercent { get; set; }

        public decimal? FutureQty { get; set; }

        public decimal? OnHandQty { get; set; }

        public DateOnly? LastAdjDate { get; set; }

        public decimal? BaseP1Percent
        {
            get
            {
                if (!BaseP1.HasValue || !BaseRecentCost.HasValue)
                    return null;

                if (BaseP1.Value == 0)
                    return null;

                return Utilities.Rounding(
                    (BaseP1.Value - BaseRecentCost.Value) / BaseP1.Value,
                    4
                );
            }
        }

        public string? PrimaryImageUrl { get; set; }

        public decimal? UpcomingQty { get; set; }

        public decimal? ActualSaftyInventory { get; set; }

        public decimal? RefillInventory { get; set; }

        public int? CategoryId { get; set; }

        public string? FullCategoryPath { get; set; }

        public int? StorageId { get; set; }

        public string? StorageName { get; set; }

        public decimal? CaseLength { get; set; }
        public decimal? CaseWidth { get; set; }
        public decimal? CaseHeight { get; set; }
        public decimal? CaseVolumeInCubicMeter { get; set; }
        public bool IsVolumeManual { get; set; }
    }
}
