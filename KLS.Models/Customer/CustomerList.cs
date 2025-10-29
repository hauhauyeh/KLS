using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CustomerList
    {
        [Key]
        public int PayeeId { get; set; }

        public string? Region { get; set; }

        public string? DefaultRoute { get; set; }

        public string? PayeeName { get; set; }

        public int? SalesRep { get; set; }

        public string? SalesRepName { get; set; }

        public bool HasOwnList { get; set; }

        public bool IsLinkOwnShared { get; set; }

        public int? DefaultQuoteId { get; set; }

        public string? DefQuoteName { get; set; }

        public DateOnly? LastOrderDate { get; set; }

        public string? CallSchedule { get; set; }

        public decimal? Balance { get; set; }

        public int? BillId { get; set; }

        public string? BillName { get; set; }

        public decimal? CreditLimit { get; set; }

        public string? TermName { get; set; }

        public int? AvgPayDay { get; set; }

        public bool IsClosed { get; set; }

        public int? GracePeriod { get; set; }

        public bool IsCreditHold { get; set; }

        public int? DueInvoiceCount { get; set; }

        public int? DueInvoiceDays { get; set; }

        public decimal? Payee30Volume { get; set; }

        public decimal? BaseMarkup { get; set; }
    }
}
