using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class LiabilityPaymentReq
    {
        public int VendorPaymentId { get; set; }

        public int PayeeId { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public int? FromAccountId { get; set; }

        public decimal? PaymentAmount { get; set; }

        public string? Notes { get; set; }

        public int? AccountId1 { get; set; }

        public int? AccountId2 { get; set; }

        public int? AccountId3 { get; set; }

        public decimal? Amount1 { get; set; }

        public decimal? Amount2 { get; set; }

        public decimal? Amount3 { get; set; }
    }
}
