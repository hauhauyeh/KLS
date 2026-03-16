using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptOrderGuideItem
    {
        [Key]
        public int QuoteId { get; set; }

        public string? ItemName { get; set; }

        public string? ItemName2 { get; set; }

        public string? Unit { get; set; }

        public bool IsShared { get; set; }

        public string? Cat0 { get; set; }

        public string? Cat1 { get; set; }
    }
}
