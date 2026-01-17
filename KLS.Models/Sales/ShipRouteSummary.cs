using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ShipRouteSummary
    {
        [Key]
        public string ShipRoute { get; set; }

        public int DropCount { get; set; }

        public decimal? RouteTotal { get; set; }

        public bool HasRouteOrder { get; set; }

        public decimal? WeightTotal { get; set; }

        [NotMapped]
        public ICollection<ShipRouteDetail>? ShipRouteDetails { get; set; }
    }
}
