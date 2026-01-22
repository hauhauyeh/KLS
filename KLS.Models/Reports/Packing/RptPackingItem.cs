using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptPackingItem
    {
        [Key]
        public int Id { get; set; }

        public string? StorageName { get; set; }

        public string? ItemName { get; set; }

        public string? ItemName2 { get; set; }

        public string? Unit { get; set; }

        public decimal? ShipQty { get; set; }

        public string? Comment { get; set; }

        public string? ShipRoute { get; set; }

        public string? LoadRoute { get; set; }

        public decimal? ItemWeight { get; set; }

        public string? Aisle { get; set; }

        public string? Bay { get; set; }
    }
}
