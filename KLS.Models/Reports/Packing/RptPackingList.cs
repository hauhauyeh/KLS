using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptPackingList
    {
        // Optional title override for packing-style reports that are not the normal
        // route/sales PackingList document, such as Harvills or Store Total.
        public string? ReportTitle { get; set; }

        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public int? SalesId { get; set; }

        public string? PayeeName { get; set; }

        public string? TruckNumber { get; set; }

        //public string? LoadOrder { get; set; }

        public int DropCount { get; set; }

        public List<string>? CustomerNames { get; set; }

        public List<PackingListStorage>? Storages { get; set; }

        public decimal? TotalWeight { get { return Storages?.Sum(c => c.WeightTotal); } }
    }

    public class PackingListStorage
    {
        public string? StorageName { get; set; }

        public List<PackingListProduct>? Products { get; set; }

        public decimal? WeightTotal { get; set; }
    }

    public class PackingListProduct
    {
        public string? ItemName { get; set; }

        public string? Comment { get; set; }

        // Subtitle is used only for lbs-only split boxes so users can tell
        // otherwise-identical customer rows apart without changing normal boxes.
        public string? Subtitle { get; set; }

        public List<RptPackingItem>? Items { get; set; }

        // TotalSplit renders one item box with combined unit totals first, then
        // optional indented split-detail lines underneath the affected unit.
        public List<PackingListUnitLine>? UnitLines { get; set; }
    }

    public class PackingListUnitLine
    {
        public decimal? ShipQty { get; set; }

        public string? Unit { get; set; }

        public bool IsSplitDetail { get; set; }

        public string? Subtitle { get; set; }
    }
}
