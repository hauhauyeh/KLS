using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesRouteDetail
    {
        public SalesRouteDetail()
        {
            CreatedAt = DateTime.UtcNow;
            FactorToBase = 1;
            BaseQty = 0;
            ReturnType = "UNTRACKED";
            ResolutionStatus = "PENDING";
        }

        [Key]
        public int RouteDetailId { get; set; }

        public int SalesRouteId { get; set; }

        public int ItemId { get; set; }

        public int ItemUnitId { get; set; }

        public string? Unit { get; set; }

        public decimal? Qty { get; set; }

        public decimal? FactorToBase { get; set; }

        public decimal? BaseQty { get; set; }

        public bool IsMatch { get; set; }

        public int? Fault { get; set; }

        public string? Notes { get; set; }

        public string? ReturnType { get; set; }

        public string? ResolutionStatus { get; set; }

        public DateTime? ResolvedAt { get; set; }

        public int? ResolvedBy { get; set; }

        public int? InventoryAdjId { get; set; }

        public int? InventoryAdjDetailId { get; set; }

        public int? CreditMemoSalesId { get; set; }

        public DateTime CreatedAt { get; set; }


        [NotMapped]
        public string? ItemCode { get; set; }

        [NotMapped]
        public string? ItemName { get; set; }

        [NotMapped]
        public string? PackSize { get; set; }

        [NotMapped]
        public DateOnly ShipDate { get; set; }

        [NotMapped]
        public string? ShipRoute { get; set; }
    }
}
