using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PayPeriod
    {
        [Key]
        public DateOnly? PayrollStartDate { get; set; }

        public DateOnly? PayrollEndDate { get; set; }
    }
}
