using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempTransferFund
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TempTFId { get; set; }

        public int EmpId { get; set; }

        public int TFId { get; set; }

        public int CustomerPaymentId { get; set; }

        public decimal? DepositAmount { get; set; }

        public string? Notes { get; set; }

        public bool IsApplied { get; set; }
    }
}
