namespace KLS.Models
{
    public class WorksheetPatternReportRequest
    {
        public string? Search { get; set; }

        public int? CategoryId { get; set; }

        public int? PayeeId { get; set; }

        public bool? ShowInactive { get; set; }

        public string? Filterby { get; set; }
    }
}
