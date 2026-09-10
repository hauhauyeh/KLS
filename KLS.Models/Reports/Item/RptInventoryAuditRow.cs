using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models.Reports
{
    public class RptInventoryAuditRow
    {
        [Key]
        public Int64 TxDetailId { get; set; }

        public Int64? TxId { get; set; }

        public DateOnly? TxDate { get; set; }

        public string? SourceDocType { get; set; }

        public int? SourceDocNumber { get; set; }

        public string? SalesDocNumber { get; set; }

        public int? PayeeId { get; set; }

        public string? PayeeName { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? InventoryQty { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? ClosingQty { get; set; }
    }
}
