using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PaymentMethodList
    {
        [Key]
        public int PaymentMethodId { get; set; }

        public bool IsACH { get; set; }

        public bool IsPrimary { get; set; }

        public string? AccountType { get; set; }

        public string? AccountName { get; set; }

        public string? ExpMonth { get; set; }

        public string? ExpYear { get; set; }

        public string? Last4 { get; set; }

        public decimal? FeePercent { get; set; }

        public string? Notes { get; set; }
    }
}
