using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace KLS.Services
{
    public class JWTService : IJWTService
    {
        private readonly AppSettings _appSettings;
        private readonly byte[] _key;

        public JWTService(IOptions<AppSettings> appSettings)
        {
            _appSettings = appSettings.Value;
            _key = Encoding.ASCII.GetBytes(_appSettings.Secret);
        }

        public string GenerateJwtToken(JWTClaim userClaim)
        {
            var claims = new List<Claim>
            {
                new Claim("jwtclaim", JsonSerializer.Serialize(userClaim))
            };

            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(claims),
                Expires = DateTime.UtcNow.AddMinutes(_appSettings.TokenValidity),
                SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(_key), SecurityAlgorithms.HmacSha256Signature)
            };

            var tokenHandler = new JwtSecurityTokenHandler();
            var token = tokenHandler.CreateToken(tokenDescriptor);

            return tokenHandler.WriteToken(token);
        }

        public JWTClaim? ValidateJwtToken(string token)
        {
            return ValidateTokenInternal(token, validateLifetime: true);
        }

        public JWTClaim? ValidateExpiredToken(string token)
        {
            return ValidateTokenInternal(token, validateLifetime: false);
        }

        private JWTClaim? ValidateTokenInternal(string token, bool validateLifetime)
        {
            try
            {
                var tokenHandler = new JwtSecurityTokenHandler();
                var validationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(_key),
                    ValidateIssuer = false,
                    ValidateAudience = false,
                    ClockSkew = TimeSpan.Zero,
                    ValidateLifetime = validateLifetime
                };

                tokenHandler.ValidateToken(token, validationParameters, out SecurityToken validatedToken);

                var jwtToken = (JwtSecurityToken)validatedToken;
                var jwtJson = jwtToken.Claims.FirstOrDefault(x => x.Type == "jwtclaim")?.Value ?? "";

                if (string.IsNullOrEmpty(jwtJson))
                {
                    return null;
                }

                return JsonSerializer.Deserialize<JWTClaim>(jwtJson);

                //return jwtToken.Claims.FirstOrDefault(x => x.Type == "jwtclaim")?.Value ?? "";
            }
            catch
            {
                return null;
            }
        }

        public string GenerateRefreshToken()
        {
            var randomBytes = new byte[64];
            using var rng = RandomNumberGenerator.Create();
            rng.GetBytes(randomBytes);
            return Convert.ToBase64String(randomBytes);
        }

        public int RefreshTokenValidity()
        {
            return _appSettings.RefreshTokenValidity;
        }
    }
}
