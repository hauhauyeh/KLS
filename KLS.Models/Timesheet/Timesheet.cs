using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

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

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }


        [ForeignKey("TimesheetId")]
        public virtual ICollection<TimesheetDetail>? TimeSheetDetails { get; set; }


        public string? DayOfWeek { get { return InTime.DayOfWeek.ToString(); } }

        public virtual TimeSpan WorkingHour
        {
            get
            {
                return OutTime.HasValue ? OutTime.Value.Subtract(InTime) : new TimeSpan(0);
            }
        }

        public string? InTimeHour { get { return InTime.ToString("hh"); } }

        public string? InTimeMinute { get { return InTime.ToString("mm"); } }

        public string? InTimeAMPM { get { return InTime.ToString("tt"); } }

        public string? OutTimeHour { get { return OutTime.HasValue ? OutTime.Value.ToString("hh") : null; } }

        public string? OutTimeMinute { get { return OutTime.HasValue ? OutTime.Value.ToString("mm") : null; } }

        public string? OutTimeAMPM { get { return OutTime.HasValue ? OutTime.Value.ToString("tt") : null; } }
    }
}
