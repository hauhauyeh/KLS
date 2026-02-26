using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptResponsible
    {
        public string? ResType { get; set; }

        public List<RptResponsibleRow> Items { get; set; } = new();
    }
}
