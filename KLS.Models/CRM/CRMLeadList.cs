using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class CRMLeadList
    {
        [Key]
        public int LeadId { get; set; }

        public string? LeadName { get; set; }

        public string? ContactPerson { get; set; }

        public string? Phone { get; set; }

        public string? Email { get; set; }

        public string? Stage { get; set; }

        public string? Source { get; set; }

        public string? SalesRepName { get; set; }

        public decimal? EstimatedValue { get; set; }

        public DateOnly? NextFollowUpDate { get; set; }

        public int? ConvertedPayeeId { get; set; }

        public DateTime? CreatedAt { get; set; }
    }
}
