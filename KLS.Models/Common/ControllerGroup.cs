using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ControllerGroup
    {
        public string? GroupName { get; set; }

        public List<ControllerInfo>? Controllers { get; set; }

        public bool IsAllow { get; set; }
    }
}
