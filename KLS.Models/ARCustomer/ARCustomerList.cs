using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ARCustomerList
    {
        [Key]
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string? Region { get; set; }

        public string? DefaultRoute { get; set; }

        public string? TermName { get; set; }

        public bool IsAutoPayment { get; set; }

        public int? PaymentMethodCount { get; set; }

        public string? SalesRepName { get; set; }

        public decimal? PayeeCurrent { get; set; }

        public decimal? Payee5 { get; set; }

        public decimal? Payee30 { get; set; }

        public decimal? Payee60 { get; set; }

        public decimal? Payee90 { get; set; }

        public decimal? PayeeOver90 { get; set; }

        public decimal? PayeeTotalDue { get; set; }

        public decimal? PayeePastDue { get; set; }

        public decimal? Balance { get; set; }

        public int? GracePeriod { get; set; }

        public int? DueInvoiceDays { get; set; }

        public DateOnly? LastPaymentDate { get; set; }

        public int? LastPaidDaysAgo { get; set; }

        public decimal? LastPaymentAmount { get; set; }

        public DateOnly? LastOrderDate { get; set; }

        public int? LastOrderDaysAgo { get; set; }

        public decimal? LastOrderAmount { get; set; }

        public DateOnly? FirstDueDate { get; set; }

        public int? AvgPaymentDays { get; set; }

        public bool IsCreditHold { get; set; }

        public int? MaxDueAgingDays { get; set; }

        public decimal? InvoiceAgeCurrent { get; set; }
        public decimal? InvoiceAge5 { get; set; }
        public decimal? InvoiceAge30 { get; set; }
        public decimal? InvoiceAge60 { get; set; }
        public decimal? InvoiceAge90 { get; set; }
        public decimal? InvoiceAgeOver90 { get; set; }
    }
}
