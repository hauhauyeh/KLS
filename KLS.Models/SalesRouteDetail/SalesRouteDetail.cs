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
        }

        [Key]
        public int RouteDetailId { get; set; }

        public int SalesRouteId { get; set; }

        public int ItemId { get; set; }

        public int ItemUnitId { get; set; }

        public string? Unit { get; set; }

        public decimal? Qty { get; set; }

        public bool IsMatch { get; set; }

        public int? Fault { get; set; }

        public string? Notes { get; set; }

        public DateTime? CreatedAt { get; set; }


        [NotMapped]
        public string? ItemCode { get; set; }

        [NotMapped]
        public string? ItemName { get; set; }

        [NotMapped]
        public string? PackSize { get; set; }
    }
}
