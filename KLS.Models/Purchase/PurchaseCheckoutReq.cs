using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PurchaseCheckoutReq
    {
        public int PurchaseId { get; set; } 

        public int PayeeId { get; set; }

        public string? VendorDocNumber { get; set; }

        public string? ContainerNumber { get; set; }

        public DateOnly? PurchaseDate { get; set; }

        public DateOnly? ArrivalDate { get; set; }

        public DateOnly? InvoiceDate { get; set; }

        public DateOnly? DueDate { get; set; }

        public string? FactorPO { get; set; }

        public string? Notes { get; set; }

        public int StageId { get; set; }

        public int? PalletCount { get; set; }
    }
}
