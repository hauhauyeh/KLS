using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemHistorySales
    {
        [Key]
        public int SalesDetailId { get; set; }

        public int SalesNumber { get; set; }

        public int SalesId { get; set; }

        public DateOnly? ShipDate { get; set; }

        public int? ShipId { get; set; }

        public string? PayeeName { get; set; }

        public decimal? ShipQty { get; set; }

        public string? Unit { get; set; }

        public decimal? UnitPrice { get; set; }


        [NotMapped]
        public bool IsPdfExist { get; set; }
    }
}
