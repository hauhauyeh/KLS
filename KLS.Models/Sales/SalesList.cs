using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Reflection.Metadata.Ecma335;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesList
    {
        [Key]
        public int SalesId { get; set; }

        public int SalesNumber { get; set; }

        public DateTime? SalesDate { get; set; }

        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public int? ShipId { get; set; }

        public decimal? SalesTotal { get; set; }

        public string? Instruction { get; set; }

        public decimal? AmountDue { get; set; }

        public string? CustPONumber { get; set; }

        public int? RouteOrder { get; set; }

        public bool IsLocked { get; set; }

        public bool IsLoadSeparate { get; set; }

        public int? LoadOrder { get; set; }

        public string? PayeeName { get; set; }

        public string? City { get; set; }

        [NotMapped]
        public bool IsPdfExist { get; set; }
    }
}
