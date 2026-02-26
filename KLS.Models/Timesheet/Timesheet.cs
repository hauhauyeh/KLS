using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using KLS.Common;

namespace KLS.Models
{
    public class Timesheet
    {
        public Timesheet()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TimesheetId { get; set; }

        public int TimesheetNumber { get; set; }

        public int PayeeId { get; set; }

        public DateTime InTime { get; set; }

        public DateTime? OutTime { get; set; }

        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }


        [ForeignKey("TimesheetId")]
        public virtual ICollection<TimesheetDetail>? TimeSheetDetails { get; set; }

        // Display-only / computed: NOT MAPPED
        [NotMapped] public string? PayeeName { get; set; }

        [NotMapped]
        public DateTime InTimeLocal
            => Utilities.ConvertFromUtcToLocal(InTime, UserContext.UserTimezone);

        [NotMapped]
        public DateTime? OutTimeLocal
            => OutTime.HasValue ? Utilities.ConvertFromUtcToLocal(OutTime.Value, UserContext.UserTimezone) : null;

        [NotMapped]
        public string DayOfWeek => InTimeLocal.DayOfWeek.ToString();

        [NotMapped]
        public TimeSpan WorkingHour => OutTimeLocal.HasValue ? OutTimeLocal.Value - InTimeLocal : TimeSpan.Zero;

        [NotMapped]
        public string InTimeHour => InTimeLocal.ToString("hh");

        [NotMapped]
        public string InTimeMinute => InTimeLocal.ToString("mm");

        [NotMapped]
        public string InTimeAMPM => InTimeLocal.ToString("tt");

        [NotMapped]
        public string? OutTimeHour => OutTimeLocal?.ToString("hh");

        [NotMapped]
        public string? OutTimeMinute => OutTimeLocal?.ToString("mm");

        [NotMapped]
        public string? OutTimeAMPM => OutTimeLocal?.ToString("tt");
    }
}
