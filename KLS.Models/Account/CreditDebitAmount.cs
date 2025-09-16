using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CreditDebitAmount
    {
        [Key]
        public decimal CrDeAmount { get; set; }

        public decimal DebitAmount { get; set; }

        public decimal CreditAmount { get; set; }
    }
}
