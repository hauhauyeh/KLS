using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptCheckPrint
    {
        [Key]
        public int PaymentNumber { get; set; }
        public DateOnly? PaymentDate { get; set; }
        public string? PaymentMethod { get; set; }
        public int FromAccountId { get; set; }
        public string? ReferenceId { get; set; }
        public decimal PaymentAmount { get; set; }
        public string? CompanyName { get; set; }
        public string? PaymentAddress { get; set; }
        public string? PaymentCity { get; set; }
        public string? PaymentState { get; set; }
        public string? PaymentZipCode { get; set; }
        public string? AmtInWords { get; set; }
        public string? RoutingNumber { get; set; }
        public string? AccountNumber { get; set; }
    }
}
