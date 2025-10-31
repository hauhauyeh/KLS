using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CheckRegister
    {
        [Key]
        public int PaymentNumber { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PayeeName { get; set; }

        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public int? FromAccountId { get; set; }

        public decimal? PaymentAmount { get; set; }

        public bool IsLocked { get; set; }

        public DateTime? BankDate { get; set; }

        public DateTime? MailDate { get; set; }

        public string? AccountName { get; set; }
    }
}
