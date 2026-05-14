using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TimesheetList
    {
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string? HourOrSalary { get; set; }

        public double? TotalHours { get; set; }

        public decimal? TotalSalary { get; set; }

        public ICollection<Timesheet>? Timesheets { get; set; }
    }
}
