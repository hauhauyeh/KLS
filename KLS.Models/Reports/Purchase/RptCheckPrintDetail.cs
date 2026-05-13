using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptCheckPrintDetail
    {
        [Key]
        public int PaymentDetailId { get; set; }
        public int PurchaseNumber { get; set; }
        public DateOnly? ArrivalDate { get; set; }
        public string? VendorDocNumber { get; set; }
        public decimal PurchaseTotal { get; set; }
    }
}
