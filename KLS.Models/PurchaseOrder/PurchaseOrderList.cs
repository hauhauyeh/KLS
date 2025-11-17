using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PurchaseOrderList
    {
        [Key]
        public int POId { get; set; }

        public int PONumber { get; set; }

        public int PayeeId { get; set; }

        public string? VendorDocNumber { get; set; }

        public DateOnly? PurchaseDate { get; set; }

        public string? ContainerNumber { get; set; }

        public DateOnly? EstArrivalDate { get; set; }

        public string? PayeeName { get; set; }

        public decimal? VendorTotal { get; set; }

        public decimal? POTotal { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public int? FromAccountId { get; set; }

        public decimal? AdvanceTotal { get; set; }

        public string? Notes { get; set; }

        public int? PurchaseId { get; set; }

        public bool IsPOCopyToBill { get { return PurchaseId > 0; } }
    }
}
