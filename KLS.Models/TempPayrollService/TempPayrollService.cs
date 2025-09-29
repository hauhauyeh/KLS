using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempPayrollService
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TempPayrollId { get; set; }

        public int EmpId { get; set; }

        public int PayrollServiceId { get; set; }

        public int PayeeId { get; set; }

        public string? ServiceCode { get; set; }

        public string? FromAccount { get; set; }

        public string? ReferenceId { get; set; }

        public decimal? PaymentAmount { get; set; }


        [NotMapped]
        public string? PayeeName { get; set; }
    }
}
