using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ForgotPassword
    {
        public string? Username { get; set; }

        public string? ResetUrl { get; set; }
    }
}
