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

        public int SalesNum { get; set; }

        public DateTime? SalesDate { get; set; }

        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public int? RouteOrder { get; set; }

        public int? ShipId { get; set; }

        public int? BillId { get; set; }

        public int? SalesRepId { get; set; }

        public string? PmtTerm { get; set; }

        public decimal? SubTotal { get; set; }

        public decimal? TaxTotal { get; set; }

        public decimal? SalesTotal { get; set; }

        public decimal? AmtDue { get; set; }

        public DateOnly? DueDate { get; set; }

        public DateOnly? DiscDate { get; set; }

        public decimal? DiscRate { get; set; }

        public decimal? TotalPmtApplied { get; set; }

        public decimal? TotalDiscApplied { get; set; }

        public int? Aging { get; set; }

        public int? InvAging { get; set; }

        public string? Instruction { get; set; }

        public int? StageId { get; set; }

        public bool IsStmtAttached { get; set; }

        public bool IsLocked { get; set; }

        public string? CustPO { get; set; }

        public int? Deliverby { get; set; }

        public int? Enterby { get; set; }

        public int? Loadby { get; set; }

        public int? Updateby { get; set; }

        public string? TruckNum { get; set; }

        public bool IsLoadSeparate { get; set; }

        public int? LoadOrder { get; set; }

        public string? LoadRoute { get; set; }

        public decimal? SalesMargin { get; set; }

        public decimal? SalesMarginOrder { get; set; }

        public int? ShippingCarrierId { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
