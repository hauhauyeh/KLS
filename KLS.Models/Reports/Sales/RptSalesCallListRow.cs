using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptSalesCallListRow
    {
        [Key]
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string? PhoneDesc1 { get; set; }

        public string? Phone1 { get; set; }

        public string? PhoneDesc2 { get; set; }

        public string? Phone2 { get; set; }

        public DateOnly? CustLastOrderDate { get; set; }

        public int? DaysAgo { get; set; }

        public string? CustLastCallingStatus { get; set; }

        public string? CustCallSchedule { get; set; }

        public decimal? SalesTotal { get; set; }

        public string? CustRegion { get; set; }

        public string? SalesRepName { get; set; }
    }
}
