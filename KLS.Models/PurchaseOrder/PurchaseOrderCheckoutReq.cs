using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PurchaseOrderCheckoutReq
    {
        [Key]
        public int PurchaseId { get; set; }

        //public int POId { get; set; }

        public int PayeeId { get; set; }

        public DateOnly? PurchaseDate { get; set; }

        //public DateOnly? EstArrivalDate { get; set; }

        public DateOnly? ArrivalDate { get; set; }

        public string? Notes { get; set; }
    }
}
