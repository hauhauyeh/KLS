using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AcctList
    {
        public int AcctId { get; set; }

        public int? AcctTypeId { get; set; }

        public string? AcctCode { get; set; }

        public string? AcctName { get; set; }

        public decimal? AcctBalance { get; set; }

        public bool Inactive { get; set; }
    }
}
