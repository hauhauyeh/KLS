using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesUpdateReq
    {
        public int SalesId { get; set; }


        public string? ShipRoute { get; set; }

        public string? Instruction { get; set; }

        public string? CustPONumber { get; set; }

        public int? ShippingCarrierId { get; set; }

        public decimal? ShippingCharge { get; set; }

        public int? StageId { get; set; }


        //for name and date change
        public bool IsNameChange { get; set; }

        public int? PayeeId { get; set; }

        public bool IsDateChange { get; set; }

        public DateOnly? ShipDate { get; set; }
    }
}
