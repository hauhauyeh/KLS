using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class CRMFollowUp
    {
        [Key]
        public int FollowUpId { get; set; }

        public int? PayeeId { get; set; }

        public int? LeadId { get; set; }

        public string? Subject { get; set; }

        public string? Description { get; set; }

        public DateOnly? DueDate { get; set; }

        public TimeSpan? DueTime { get; set; }

        public string? Priority { get; set; }

        public string? Status { get; set; }

        public int? AssignedTo { get; set; }

        public DateTime? CompletedAt { get; set; }

        public int? CompletedBy { get; set; }

        public int? ActivityId { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public int? EnterBy { get; set; }

        public int? UpdateBy { get; set; }
    }
}
