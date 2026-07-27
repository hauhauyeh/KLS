using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ShipRouteDetail
    {
        [Key]
        public int SalesId { get; set; }

        public int SalesNumber { get; set; }

        public string? SalesDocNumber { get; set; }

        public string? ShipRoute { get; set; }

        public string? Region { get; set; }

        public int? RouteOrder { get; set; }

        public bool IsLoadSeparate { get; set; }

        public string? PayeeName { get; set; }

        public decimal? SalesTotal { get; set; }

        public double? GoogleLat { get; set; }

        public double? GoogleLong { get; set; }

        public decimal? WeightTotal { get; set; }

        public string? TruckNumber { get; set; }

        public string GoogleLatLong
        {
            get
            {
                return GoogleLat + "," + GoogleLong;
            }
        }
    }
}
