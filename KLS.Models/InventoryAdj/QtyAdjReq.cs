using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class QtyAdjReq
    {
        public DateOnly? AdjDate { get; set; }

        public int ItemId { get; set; }

        public string? OpenClose { get; set; }

        public decimal? NewQty { get; set; }

        public decimal? NewPrice { get; set; }
    }
}
