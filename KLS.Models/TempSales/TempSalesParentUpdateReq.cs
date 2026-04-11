using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempSalesParentUpdateReq
    {
        public int TempSalesId { get; set; }

        public int? ParentSalesNumber { get; set; }
    }
}
