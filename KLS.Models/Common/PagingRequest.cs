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

        public bool IsCount { get; set; }

        public DateOnly? StartDate { get; set; }

        public DateOnly? EndDate { get; set; }

        public int? Id { get; set; }

        public string? Filterby { get; set; }

        public string? SortField { get; set; }

        public string? SortOrder { get; set; }
    }
}
