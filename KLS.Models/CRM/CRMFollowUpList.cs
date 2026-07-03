using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class CRMFollowUpList
    {
        [Key]
        public int FollowUpId { get; set; }

        public int? PayeeId { get; set; }

        public int? LeadId { get; set; }

        public string? Subject { get; set; }

        public DateOnly? DueDate { get; set; }

        public TimeSpan? DueTime { get; set; }

        public string? Priority { get; set; }

        public string? Status { get; set; }

        public string? Group { get; set; }

        public string? CustomerName { get; set; }

        public string? LeadName { get; set; }

        public string? AssignedToName { get; set; }

        public int? AssignedTo { get; set; }

        public DateTime? CompletedAt { get; set; }

        public DateTime? CreatedAt { get; set; }
    }
}
