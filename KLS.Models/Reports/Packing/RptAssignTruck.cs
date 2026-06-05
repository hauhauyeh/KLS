using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptAssignTruck
    {
        [Key]
        public int SalesRouteId { get; set; }

        public string? TruckNumber { get; set; }

        public DateTime? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public string? TruckName { get; set; }

        public string? Driver { get; set; }
    }
}
