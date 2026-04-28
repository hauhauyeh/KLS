using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptServiceSummary
    {
        [Key]
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public decimal? Total { get; set; }
    }
}
