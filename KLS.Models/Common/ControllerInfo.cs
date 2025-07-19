using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ControllerInfo
    {
        public string Id => $"{Name}";

        public string? Name { get; set; }

        public string? DisplayName { get; set; }

        public string? GroupName { get; set; }

        public List<ActionInfo>? Actions { get; set; }

        public bool IsAllow { get; set; }
    }
}
