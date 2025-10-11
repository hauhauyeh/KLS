using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CheckInOut
    {
        [Key]
        public int TimeSheetId { get; set; }

        public string? EmpName { get; set; }

        public string? InOut { get; set; }

        public bool IsLastDayCheckoutForget { get; set; }
    }
}
