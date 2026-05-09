using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptResponsibleRow
    {
        [Key]
        public int AutoId { get; set; }

        public int? SalesNumber { get; set; }

        public string? ShipRoute { get; set; }

        public string? PayeeName { get; set; }

        public string? Instruction { get; set; }

        public int? ItemId { get; set; }

        public string? ItemName { get; set; }

        public string? Notes { get; set; }

        public decimal? ShipQty { get; set; }

        public decimal? BillQty { get; set; }

        public string? Unit { get; set; }

        public string? ResType { get; set; }
    }
}
