using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class SchedulerConfig
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        public string JobName { get; set; }

        public string? JobDescription { get; set; }

        public string SpName { get; set; }

        public string Frequency { get; set; }

        public TimeSpan RunTime { get; set; }

        public byte? OriginalDayOfWeek { get; set; }

        public byte? DayOfWeek { get; set; }

        public byte? DayOfMonth { get; set; }

        public bool IsEnabled { get; set; }

        public DateTime? LastRunTime { get; set; }

        public string? LastRunStatus { get; set; }

        public DateTime? NextRunTime { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
