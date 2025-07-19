using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IJWTService
    {
        string GenerateJwtToken(object userPayload);
        string ValidateJwtToken(string token);
        string ValidateExpiredToken(string token);
        string GenerateRefreshToken();
        int RefreshTokenValidity();
    }
}
