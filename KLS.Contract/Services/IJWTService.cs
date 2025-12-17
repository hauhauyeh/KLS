using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IJWTService
    {
        string GenerateJwtToken(JWTClaim userPayload);

        JWTClaim? ValidateJwtToken(string token);

        JWTClaim? ValidateExpiredToken(string token);

        string GenerateRefreshToken();

        int RefreshTokenValidity();
    }
}
