using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class MapLatLong
    {
        public string Latitude { get; set; }

        public string Longitude { get; set; }

        public string? PlaceId { get; set; }

        public string? FormatAddress { get; set; }
    }
}
