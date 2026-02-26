using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PurchaseOrder
    {
        public PurchaseOrder()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int POId { get; set; }

        public int PONumber { get; set; }

        public int PayeeId { get; set; }

        public string? VendorDocNumber { get; set; }

        public string? ContainerNumber { get; set; }

        public DateOnly? PurchaseDate { get; set; }

        public DateOnly? EstArrivalDate { get; set; }

        public decimal? VendorTotal { get; set; }

        public decimal? POTotal { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public int? FromAccountId { get; set; }

        public decimal? AdvanceTotal { get; set; }

        public string? Notes { get; set; }

        public int? PurchaseId { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public bool IsPOCopyToBill { get { return PurchaseId > 0; } }
    }
}
