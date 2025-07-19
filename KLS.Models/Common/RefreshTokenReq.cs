using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class RefreshTokenReq
    {
        public string AccessToken { get; set; }

        public string? RefreshToken { get; set; }
    }
}
