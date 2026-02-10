using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptSensitiveItem
    {
        [Key]
        public Int64 Id { get; set; }

        public DateOnly ShipDate { get; set; }

        public string? ItemName { get; set; }

        public string? ShipRoute { get; set; }

        public string? Unit { get; set; }

        public decimal? ShipQty { get; set; }
    }
}
