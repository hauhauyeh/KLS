using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempTimesheet
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TempTimesheetId { get; set; }

        public int EmpId { get; set; }

        public int TimesheetId { get; set; }

        public string? JobCode { get; set; }

        public decimal? Qty { get; set; }

        public decimal? JobRate { get; set; }

        public decimal? ExtTotal { get; set; }

        public string? Route { get; set; }

        public string? Notes { get; set; }
    }
}
