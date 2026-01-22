using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptPackingList
    {
        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public int? SalesId { get; set; }

        public string? PayeeName { get; set; }

        public string? TruckNumber { get; set; }

        public string? LoadOrder { get; set; }

        public int DropCount { get; set; }

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

        public List<RptPackingItem>? Items { get; set; }
    }
}
