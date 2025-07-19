using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Common
{
    public class AppSettings
    {
        public string? Secret { get; set; }

        public double TokenValidity { get; set; }

        public int RefreshTokenValidity { get; set; }
    }
}
