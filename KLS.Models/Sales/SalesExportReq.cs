using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesExportReq
    {
        public DateOnly? StartDate { get; set; }

        public DateOnly? EndDate { get; set; }
    }
}
