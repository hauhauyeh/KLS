using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemWebRowList
    {
        public int ItemId { get; set; }
        public string ItemCode { get; set; }
        public string ItemName { get; set; }
        public string? ItemName2 { get; set; }

        public string? ItemLongDesc { get; set; }

        public string? SetPacking { get; set; }
        public string? PackSize { get; set; }
        public decimal? LCloseQty { get; set; }
        public DateOnly? ExpiryDate { get; set; }

        public int ItemUnitId { get; set; }
        public string? Unit { get; set; }
        public string? Barcode { get; set; }
        public bool IsBaseUnit { get; set; }
        public bool IsDefaultSalesUnit { get; set; }

        // Unit ratio: BaseQty = Qty * MultipleToBase / FactorToBase. MultipleToBase is the
        // live value from ItemUnit (never snapshotted); default 1 = identity.
        public decimal? FactorToBase { get; set; }
        public int MultipleToBase { get; set; } = 1;

        public decimal? MSRP { get; set; }
        public decimal? MarketPrice { get; set; }

        public decimal? Price { get; set; }
        public decimal? Discount { get; set; }

        public string? PrimaryImageUrl { get; set; }
    }
}
