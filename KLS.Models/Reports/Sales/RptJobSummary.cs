using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptJobSummary
    {
        [Key]
        public long Rn { get; set; }

        public string? ShipRoute { get; set; }

        public DateOnly? ShipDate { get; set; }

        public decimal? RouteTotal { get; set; }

        public string? Driver { get; set; }

        public string? Loader { get; set; }
    }
}
