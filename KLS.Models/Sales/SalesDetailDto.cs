using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesDetailDto
    {
        public string? PayeeName { get; set; }

        public SalesList? Sales { get; set; }

        public ICollection<SalesDetailList>? SalesDetails { get; set; }

        public bool IsPriceZero { get; set; }
    }
}
