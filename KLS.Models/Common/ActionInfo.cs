using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ActionInfo
    {
        public string Id => $"{ControllerName}-{Name}";

        public string? Name { get; set; }

        public string? DisplayName { get; set; }

        public string? Attributes { get; set; }

        public string? ControllerName { get; set; }

        public bool IsAllow { get; set; }
    }
}
