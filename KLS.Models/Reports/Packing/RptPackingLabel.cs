using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptPackingLabel
    {
        [Key]
        public Int64 Id { get; set; }

        public int SalesNumber { get; set; }

        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public decimal? ShipQty { get; set; }

        public string? Unit { get; set; }

        public string? ItemName { get; set; }

        public string? PayeeName { get; set; }

        public string? Last3Digit { get; set; }

        public int? RouteOrder { get; set; }

        public string? Notes { get; set; }

        public string? Department { get; set; }

        public string? TruckNumber { get; set; }

        public string? LoadRoute { get; set; }

        [NotMapped]
        public int Tag { get; set; }
    }
}
