using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ResetPassword
    {
        public string? Token { get; set; }

        public string? NewPassword { get; set; }
    }
}
