using KLS.Common;
using System;
using System.Text.Json;

namespace KLS.Models
{
    public class WalmartSettings
    {
        public string? ClientId { get; set; }
        public string? ClientSecret { get; set; }
        public string? AccessToken { get; set; }
        public DateTime? TokenExpiresAt { get; set; }
        public string? MarketCode { get; set; }
        public string? CurrencyCode { get; set; }

        public bool IsTokenValid => !string.IsNullOrEmpty(AccessToken)
            && TokenExpiresAt.HasValue
            && TokenExpiresAt.Value > DateTime.UtcNow.AddSeconds(60);

        public static WalmartSettings FromEncrypted(string? encryptedJson)
        {
            if (string.IsNullOrEmpty(encryptedJson)) return new WalmartSettings();
            var json = CredentialEncryptor.Decrypt(encryptedJson);
            return JsonSerializer.Deserialize<WalmartSettings>(json) ?? new WalmartSettings();
        }

        public string ToEncrypted()
        {
            return CredentialEncryptor.Encrypt(JsonSerializer.Serialize(this));
        }
    }
}
