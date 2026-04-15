using KLS.Common;
using System;
using System.Text.Json;

namespace KLS.Models
{
    public class EbaySettings
    {
        public string? ClientId { get; set; }
        public string? ClientSecret { get; set; }
        public string? RefreshToken { get; set; }
        public string? AccessToken { get; set; }
        public DateTime? TokenExpiresAt { get; set; }
        public string? Environment { get; set; } = "Production";
        public string? MarketplaceId { get; set; } = "EBAY_US";
        public string? CurrencyCode { get; set; } = "USD";
        public string? FulfillmentPolicyId { get; set; }
        public string? PaymentPolicyId { get; set; }
        public string? ReturnPolicyId { get; set; }
        public string? Condition { get; set; } = "NEW";
        public string? DefaultCategoryId { get; set; }
        public string? MerchantLocationKey { get; set; }

        public bool IsTokenValid => !string.IsNullOrEmpty(AccessToken)
            && TokenExpiresAt.HasValue
            && TokenExpiresAt.Value > DateTime.UtcNow.AddSeconds(60);

        public bool IsSandbox => string.Equals(Environment, "Sandbox", StringComparison.OrdinalIgnoreCase);

        public static EbaySettings FromEncrypted(string? encryptedJson)
        {
            if (string.IsNullOrEmpty(encryptedJson)) return new EbaySettings();
            var json = CredentialEncryptor.Decrypt(encryptedJson);
            return JsonSerializer.Deserialize<EbaySettings>(json) ?? new EbaySettings();
        }

        public string ToEncrypted()
        {
            return CredentialEncryptor.Encrypt(JsonSerializer.Serialize(this));
        }
    }
}
