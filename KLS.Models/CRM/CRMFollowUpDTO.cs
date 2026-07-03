namespace KLS.Models
{
    public class CRMFollowUpDTO
    {
        public int FollowUpId { get; set; }

        public int? PayeeId { get; set; }

        public int? LeadId { get; set; }

        public string? Subject { get; set; }

        public string? Description { get; set; }

        public DateOnly? DueDate { get; set; }

        public TimeSpan? DueTime { get; set; }

        public string? Priority { get; set; }

        public int? AssignedTo { get; set; }
    }
}
