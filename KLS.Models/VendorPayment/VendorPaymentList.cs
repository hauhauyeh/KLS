using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class VendorPaymentList
    {
        [Key]
        public int VendorPaymentId { get; set; }

        public int PaymentNumber { get; set; }

        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public decimal? PaymentAmount { get; set; }

        public bool IsLocked { get; set; }

        public bool IsReturn1 { get; set; }

        public bool IsRedeposit { get; set; }

        public bool IsReturn2 { get; set; }

        public bool IsVoid { get; set; }

        public string? FromAccountName { get; set; }

        public bool IsPayNow { get; set; }
    }
}
