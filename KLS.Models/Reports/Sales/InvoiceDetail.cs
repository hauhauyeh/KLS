using KLS.Common;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class InvoiceDetail
    {
        [Key]
        public int AutoId { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? ItemName2 { get; set; }

        public string? PackSize { get; set; }

        public string? LineType { get; set; }

        public string? Unit { get; set; }

        public decimal? UnitPrice { get; set; }

        public decimal? ShipQty { get; set; }

        public decimal? BillQty { get; set; }

        public decimal? ExtTotal { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? BaseShipQty { get; set; }

        public string? Notes { get; set; }

        public bool IsGroup { get; set; }

        public decimal? ItemWeight { get; set; }

        public string? AisleNum { get; set; }

        public string? BayNum { get; set; }

        public string? Barcode { get; set; }

        public string? FIFOHistory { get; set; }

        public string? FIFOHistoryOrder { get; set; }

        public string? CatInvoiceDesc { get; set; }

        public string? EncodedBarcode { get { return Utilities.EAN13(Barcode); } }

        public bool IsTaxable { get; set; }
    }
}
