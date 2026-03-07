using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesExport
    {
        public int InvoiceNo { get; set; }
        public string? Customer { get; set; }
        public DateOnly? InvoiceDate { get; set; }
        public DateOnly? DueDate { get; set; }
        public string? TermName { get; set; }
        public string? Location { get; set; }
        public string? Memo { get; set; }
        public string? ItemDescription { get; set; }
        public decimal? ShipQty { get; set; }
        public decimal? UnitPrice { get; set; }
        public decimal? ExtTotal { get; set; }
        public DateTime? ServiceDate { get; set; }
    }
}
