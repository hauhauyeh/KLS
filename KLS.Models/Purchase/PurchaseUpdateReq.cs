using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PurchaseUpdateReq
    {
        public int PurchaseId { get; set; }

        public string? Notes { get; set; }

        public string? VendorDocNumber { get; set; }

        public string? ContainerNumber { get; set; }

        public DateOnly? InvoiceDate { get; set; }

        public decimal? ImportCommission { get; set; }

        public int? PalletCount { get; set; }
    }
}
