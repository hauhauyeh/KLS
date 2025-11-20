using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class JWTClaim
    {
        public JWTClaim()
        {
            Jti = Guid.NewGuid();
            Portal = "";
        }

        public Guid Jti { get; set; }

        public string Portal { get; set; }

        public string? Username { get; set; }

        public int PayeeId { get; set; }

        //use SystemUserId if Admin portal
        //use UserId if web portal (useraccount)
        public int UserId { get; set; }

        public int RoleId { get; set; }

        public bool IsAdmin { get; set; }

        public string? RefreshToken { get; set; }

        public DateTime? RefTokenExpire { get; set; }
    }
}
