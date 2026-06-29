namespace KLS.Models
{
    // Request DTO for the Item Analysis report. Inherits Search/StartDate/EndDate/SortField
    // (SortField maps to the SP's @Sortby) from ReportRequest; adds the item-analysis filters.
    public class ItemAnalysisRequest : ReportRequest
    {
        public int? CategoryId { get; set; }   // category subtree root; null = all items

        public string? GroupBy { get; set; }   // category | storage | none (defaulted to 'category' in the repo)
    }
}
