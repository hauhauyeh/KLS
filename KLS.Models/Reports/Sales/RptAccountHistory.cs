using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptAccountHistory
    {
        [Key]
        public int SalesId { get; set; }
        public int SalesNumber { get; set; }
        public string? DocType { get; set; }
        public DateTime? ShipDate { get; set; }
        public decimal SalesTotal { get; set; }
        public string? PmtApplied { get; set; }
        public string? PmtStage { get; set; }
    }
}
