using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptCustomerSalesSummary
    {
        [Key]
        public int CustomerId { get; set; }

        public string? CustomerName { get; set; }

        public decimal? M0 { get; set; }

        public decimal? M1 { get; set; }

        public decimal? M2 { get; set; }

        public decimal? M3 { get; set; }

        public decimal? YTD { get; set; }

        public decimal? LYTD { get; set; }

        public int? TotalTx { get; set; }

        // datetime (not date) because Sales.SalesDate is datetime, unlike
        // Purchase.PurchaseDate which is date in the vendor counterpart.
        public DateTime? LastSale { get; set; }
    }
}
