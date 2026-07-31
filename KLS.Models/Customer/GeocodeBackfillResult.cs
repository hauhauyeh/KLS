using System.Collections.Generic;

namespace KLS.Models
{
    public class GeocodeBackfillResult
    {
        public int Total { get; set; }

        public int Updated { get; set; }

        public int SkippedNoAddress { get; set; }

        public int SkippedAlreadyGeocoded { get; set; }

        public int Failed { get; set; }

        public List<int> FailedPayeeIds { get; set; } = new List<int>();
    }
}
