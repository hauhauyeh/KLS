using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class VendorAppliedBill
    {
        [Key]
        public int PaymentDetailId { get; set; }

        public int PurchaseId { get; set; }

        public int PurchaseNumber { get; set; }

        public DateOnly? ArrivalDate { get; set; }

        public decimal? PurchaseTotal { get; set; }

        public decimal PaymentApplied { get; set; }

        public decimal? AmountDue { get; set; }
    }
}
