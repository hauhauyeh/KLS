using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Sales
    {
        public Sales()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int SalesId { get; set; }
        public int SalesNumber { get; set; }
        public int? ParentSalesNumber { get; set; }
        public string? DocType { get; set; }

        public int? StageId { get; set; }
        public DateTime? SalesDate { get; set; }
        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }
        public int? RouteOrder { get; set; }
        public int? ShipId { get; set; }
        public int? BillId { get; set; }
        public int? SalesRepId { get; set; }
        public int? TermId { get; set; }

        public decimal? SubTotal { get; set; }
        public decimal? TaxableTotal { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? TaxPercent { get; set; }
        public decimal? TaxTotal { get; set; }
        public decimal? SalesTotal { get; set; }
        public decimal? AmountDue { get; set; }

        public DateOnly? DueDate { get; set; }
        public DateOnly? DiscountDate { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? DiscountPercent { get; set; }
        public decimal? PaymentApplied { get; set; }
        public decimal? DiscountApplied { get; set; }

        public int? Aging { get; set; }
        public int? InvoiceAging { get; set; }

        public string? Instruction { get; set; }
        public string? CustPONumber { get; set; }
        public string? TruckNumber { get; set; }

        public int? ShippingCarrierId { get; set; }
        public string? TrackingNo { get; set; }
        public string? ExternalId { get; set; }

        public bool IsLoadSeparate { get; set; }
        public int? LoadOrder { get; set; }
        public string? LoadRoute { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? SalesMarginPercent { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? SalesMarginOrderPercent { get; set; }

        public bool IsLocked { get; set; }
        public bool IsStatementAttached { get; set; }

        public int? Deliverby { get; set; }
        public int? Enterby { get; set; }
        public int? Loadby { get; set; }
        public int? Updateby { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }


        [NotMapped]
        public bool IsPastDue => DateOnly.FromDateTime(DateTime.Now) > DueDate;
    }
}
