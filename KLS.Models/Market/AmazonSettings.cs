using KLS.Common;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AmazonSettings
    {
        public string? ClientId { get; set; }
        public string? ClientSecret { get; set; }
        public string? RefreshToken { get; set; }
        public string? AccessToken { get; set; }
        public DateTime? TokenExpiresAt { get; set; }
        public string? SellerId { get; set; }
        public string? MarketplaceId { get; set; }

        public bool IsTokenValid => !string.IsNullOrEmpty(AccessToken)
            && TokenExpiresAt.HasValue
            && TokenExpiresAt.Value > DateTime.UtcNow.AddSeconds(60);

        public static AmazonSettings FromEncrypted(string? encryptedJson)
        {
            if (string.IsNullOrEmpty(encryptedJson)) return new AmazonSettings();
            var json = CredentialEncryptor.Decrypt(encryptedJson);
            return JsonSerializer.Deserialize<AmazonSettings>(json) ?? new AmazonSettings();
        }

        public string ToEncrypted()
        {
            return CredentialEncryptor.Encrypt(JsonSerializer.Serialize(this));
        }
    }
}
