using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class DeliverSchedule
    {
        [Key]
        public int DeliverScheduleId { get; set; }

        public int PayeeId { get; set; }

        public string ScheduleType { get; set; } = string.Empty;

        public DateOnly? StartDate { get; set; }

        public DateOnly? EndDate { get; set; }

        public int? WeekInterval { get; set; }

        public int? DayOfWeek { get; set; }

        public int? WeekOfMonth { get; set; }

        public int? DayOfMonth { get; set; }

        public bool IsActive { get; set; }

        public string? Notes { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public string? EnterBy { get; set; }

        public string? UpdateBy { get; set; }
    }
}
