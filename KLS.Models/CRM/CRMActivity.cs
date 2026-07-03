using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class CRMActivity
    {
        [Key]
        public int ActivityId { get; set; }

        public int? PayeeId { get; set; }

        public int? LeadId { get; set; }

        public string? ActivityType { get; set; }

        public string? Subject { get; set; }

        public string? Description { get; set; }

        public DateTime? ActivityDate { get; set; }

        public int? Duration { get; set; }

        public string? Outcome { get; set; }

        public int? SalesRepId { get; set; }

        public DateTime? CreatedAt { get; set; }

        public int? EnterBy { get; set; }
    }
}
