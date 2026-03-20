using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptPayroll
    {
        [Key]
        public int VendorPaymentId { get; set; }

        public int? PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public DateOnly? PaymentDate { get; set; }

        public string? PaymentMethod { get; set; }

        public string? ReferenceId { get; set; }

        public DateOnly? PayPeriodStart { get; set; }

        public DateOnly? PayPeriodEnd { get; set; }

        public decimal? GrossPay { get; set; }

        public decimal? EmpOASDI { get; set; }

        public decimal? EmpHI { get; set; }

        public decimal? EmpFWH { get; set; }

        public decimal? CompanyOASDI { get; set; }

        public decimal? CompanyHI { get; set; }

        public decimal? CompanyFUTA { get; set; }

        public decimal? CompanySUTA { get; set; }

        public decimal? NetPay { get; set; }

        public decimal? Garnishment { get; set; }

        public decimal? LoanRepayment { get; set; }

        public decimal? ChildSup1 { get; set; }

        public decimal? Cash { get; set; }

        public decimal? Reimbursement { get; set; }

        public decimal? Deduction { get; set; }
    }
}
