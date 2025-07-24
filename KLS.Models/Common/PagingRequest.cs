using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PagingRequest
    {
        public PagingRequest()
        {
            Pageno = 1;
            Pagesize = 50;
        }

        public int Pageno { get; set; }

        public int Pagesize { get; set; }

        public string? Search { get; set; }

        public bool? Status { get; set; }

        public string? Filterby { get; set; }

        public string? Content { get; set; }

        public string? Sortby { get; set; }

        public bool IsCount { get; set; }

        public DateTime? StartDate { get; set; }

        public DateTime? EndDate { get; set; }

        public int? EmpId { get; set; }

        public int? PayeeId { get; set; }

        public string? AcctCode { get; set; }

        public string? PmtMethod { get; set; }

        public string? Category { get; set; }

        public bool IsPaging { get; set; }
    }
}
