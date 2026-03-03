using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptSalesDaily
    {
        [Key]
        public Int64 Id { get; set; }

        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public string? PayeeName { get; set; }

        public int? SalesNumber { get; set; }

        public decimal? SalesTotal { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? SalesPercent { get; set; }

        public decimal? Cost { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? MarginPercent { get; set; }

        public string? AccountName { get; set; }
    }
}
