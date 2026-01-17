using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemQuoteBuildReq
    {
        public int PayeeId { get; set; }

        public bool IsAppend { get; set; }

        public int? TargetCustId { get; set; }

        public string? BuildMode { get; set; }

        public string? CatIds { get; set; }

        public bool BuildWithPrice { get; set; }
    }
}
