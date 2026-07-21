namespace KLS.Models
{
    public class CRMFollowUpCompleteReq
    {
        public string? ActivityType { get; set; }

        public string? Subject { get; set; }

        public string? Description { get; set; }

        public string? Outcome { get; set; }

        public DateTime? ActivityDate { get; set; }

        public int? Duration { get; set; }

        public CRMFollowUpNextReq? Next { get; set; }
    }

    public class CRMFollowUpNextReq
    {
        public string? Subject { get; set; }

        public string? Description { get; set; }

        public DateOnly? DueDate { get; set; }

        public TimeSpan? DueTime { get; set; }

        public string? Priority { get; set; }

        public int? AssignedTo { get; set; }
    }

    public class CRMFollowUpCompleteResult
    {
        public CRMActivity Activity { get; set; } = null!;

        public CRMFollowUp FollowUp { get; set; } = null!;

        public CRMFollowUp? NextFollowUp { get; set; }
    }
}
