using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PayrollInjectEmpReq
    {
        public int PayOption { get; set; }

        public DateOnly? PayDate { get; set; }
    }
}
