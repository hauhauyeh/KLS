using Microsoft.Extensions.Options;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text;
using KLS.Common;
using System.IdentityModel.Tokens.Jwt;
using Microsoft.IdentityModel.Tokens;
using KLS.Services.Interfaces;

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

        public string GenerateJwtToken(object userPayload)
        {
            var claims = new[]
            {
                new Claim("user", JsonSerializer.Serialize(userPayload))
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

        public string ValidateJwtToken(string token)
        {
            return ValidateTokenInternal(token, validateLifetime: true);
        }

        public string ValidateExpiredToken(string token)
        {
            return ValidateTokenInternal(token, validateLifetime: false);
        }

        private string ValidateTokenInternal(string token, bool validateLifetime)
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
                return jwtToken.Claims.FirstOrDefault(x => x.Type == "user")?.Value ?? "";
            }
            catch
            {
                return "";
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
