using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AssignTruck
    {
        public string? TruckNumber { get; set; }

        public ICollection<SalesRoute>? Routes { get; set; }

        public int? DriverId { get; set; }

        public string? DriverName { get; set; }

        public string? RouteNames
        {
            get
            {
                return Routes == null ? "" : string.Join(", ", Routes.Select(c => c.ShipRoute));
            }
        }
    }
}
