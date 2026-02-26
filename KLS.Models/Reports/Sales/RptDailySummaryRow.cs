using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptDailySummaryRow
    {
        [Key]
        public int? SalesNumber { get; set; }

        public int? StageId { get; set; }

        public DateOnly ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public string? PayeeName { get; set; }

        public string? Instruction { get; set; }

        public decimal? SalesTotal { get; set; }

        public string? Driver { get; set; }

        public string? Loader { get; set; }

        public string? Checker { get; set; }

        public string? TruckNumber { get; set; }

        public string? Officer { get; set; }
    }
}
