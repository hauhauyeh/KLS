using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CheckInOutReq
    {
        public int PayeeId { get; set; }

        public bool IsDetailSave { get; set; }

        public bool IsDetailAdd { get; set; }
    }
}
