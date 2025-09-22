using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class RolePermissionReq
    {
        public int RoleId { get; set; }

        public ICollection<ControllerGroup>? Permission { get; set; }
    }
}
