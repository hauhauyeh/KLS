using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempItemQuoteReq
    {
        public int PayeeId { get; set; }

        public string? SortField { get; set; }

        public string? SortOrder { get; set; }

        public int? TempId { get; set; }
    }
}
