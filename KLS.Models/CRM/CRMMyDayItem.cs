using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class CRMMyDayItem
    {
        [Key]
        public int FollowUpId { get; set; }

        public int? LeadId { get; set; }

        public int? PayeeId { get; set; }

        public int? ConvertedPayeeId { get; set; }

        public string? DisplayName { get; set; }

        public string? Subject { get; set; }

        public string? Priority { get; set; }

        public DateOnly? DueDate { get; set; }

        public TimeSpan? DueTime { get; set; }

        public string? Bucket { get; set; }
    }
}
