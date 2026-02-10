using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptLoadingItem
    {
        [Key]
        public int AutoId { get; set; }

        public string? Department { get; set; }

        public int? DepartmentOrder { get; set; }

        public string? StorageName { get; set; }

        public string? ItemName { get; set; }

        public string? Comment { get; set; }

        public decimal? ShipQty { get; set; }

        public string? Unit { get; set; }

        public string? ShipRoute { get; set; }

        public string? LoadRoute { get; set; }

        public string? ItemBoxDesc { get; set; }
    }
}
