using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PurchaseOrderInjectReq
    {
        public int POId { get; set; }

        public int EmpId { get; set; }

        public int PayeeId { get; set; }
    }
}
