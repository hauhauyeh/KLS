using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptHarvillsItem
    {
        [Key]
        public int Id { get; set; }

        public int ItemId { get; set; }

        public DateOnly ShipDate { get; set; }

        public string? Section { get; set; }

        public string? ItemName { get; set; }

        public string? Comment { get; set; }

        public decimal? ShipQty { get; set; }

        public string? Unit { get; set; }
    }
}
