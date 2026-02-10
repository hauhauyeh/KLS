using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class LiabilityTxList
    {
        [Key]
        public Int64 Rn { get; set; }

        public int? PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string? PayeeType { get; set; }

        public DateOnly TxDate { get; set; }

        public int SourceDocNumber { get; set; }

        public string? SourceDocType { get; set; }

        public string? PaymentMethod { get; set; }

        public string? AccountName { get; set; }

        public string? ReferenceId { get; set; }

        public decimal? Amount { get; set; }

        public bool IsLocked { get; set; }

        public decimal? AccountBalance { get; set; }

        public int? VendorPaymentId { get; set; }
    }
}
