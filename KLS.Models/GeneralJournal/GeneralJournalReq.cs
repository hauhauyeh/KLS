using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class GeneralJournalReq : PagingRequest
    {
        public DateOnly? GJDate { get; set; }
    }
}
