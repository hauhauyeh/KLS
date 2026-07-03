namespace KLS.Models
{
    public class CRMActivityDTO
    {
        public int? PayeeId { get; set; }

        public int? LeadId { get; set; }

        public string? ActivityType { get; set; }

        public string? Subject { get; set; }

        public string? Description { get; set; }

        public DateTime? ActivityDate { get; set; }

        public int? Duration { get; set; }

        public string? Outcome { get; set; }

        public CRMFollowUpInline? FollowUp { get; set; }
    }

    public class CRMFollowUpInline
    {
        public string? Subject { get; set; }

        public DateOnly? DueDate { get; set; }

        public string? Priority { get; set; }
    }
}
