using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ChartAccountList
    {
        public ChartAccountList()
        {
            IsCollapsed = true;
        }

        public string? AcctCategory { get; set; }

        public IQueryable<AcctList>? Accounts { get; set; }

        public bool IsCollapsed { get; set; }
    }
}
