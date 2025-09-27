using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PayrollServiceDTO
    {
        [Key]
        public int PayrollNumber { get; set; }

        public DateOnly? PayrollDate { get; set; }

        public DateOnly? PayrollStartDate { get; set; }

        public DateOnly? PayrollEndDate { get; set; }

        public decimal? DirectDeposit { get; set; }

        public decimal? CheckPay { get; set; }

        public string? FromAccount { get; set; }

        public string? AccountName { get; set; }

        public bool IsLocked { get; set; }
    }
}
