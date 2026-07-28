using KLS.Common;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptInvoice
    {
        public Company? Company { get; set; }

        public Invoice? Invoice { get; set; }

        public List<InvoiceDetail>? InvoiceDetails { get; set; }

        public RptCustStmt? Statement { get; set; }

        public Payee? ShippingCarrier { get; set; }

        public bool HasDiscount { get; set; }

        public bool UseSalesDocNumber { get; set; }

        public string SalesDisplayNumber
        {
            get
            {
                if (UseSalesDocNumber && !string.IsNullOrWhiteSpace(Invoice?.SalesDocNumber))
                    return Invoice.SalesDocNumber;

                return Invoice?.SalesNumber.ToString() ?? string.Empty;
            }
        }

        public string GetSalesDisplayNumber(KLS.Models.Sales? sales)
        {
            if (UseSalesDocNumber && !string.IsNullOrWhiteSpace(sales?.SalesDocNumber))
                return sales.SalesDocNumber;

            return sales?.SalesNumber.ToString() ?? string.Empty;
        }

        public int? TotalItems
        {
            get
            {
                return InvoiceDetails?
                    .Where(c => c.ItemCode != null)
                    .GroupBy(c => c.ItemCode).Count();
            }
        }

        public decimal? TotalCases
        {
            get
            {
                return InvoiceDetails?
                    .Where(c => c.LineType == EnumHelper.LineType.I.ToString())
                    .Sum(c => c.BaseShipQty);
            }
        }

        public decimal? TotalWeight
        {
            get
            {
                return InvoiceDetails?.Sum(c => c.ItemWeight);
            }
        }
    }
}
