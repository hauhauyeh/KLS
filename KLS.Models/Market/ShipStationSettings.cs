using KLS.Common;
using System.Text.Json;

namespace KLS.Models
{
    public class ShipStationSettings
    {
        public string? ApiKey { get; set; }
        public string? ApiSecret { get; set; }
        public int? StoreId { get; set; }

        public string? WebhookSecret { get; set; }
        public int? OrderNotifyWebhookId { get; set; }
        public int? ShipNotifyWebhookId { get; set; }

        public static ShipStationSettings FromEncrypted(string? encryptedJson)
        {
            if (string.IsNullOrEmpty(encryptedJson)) return new ShipStationSettings();
            var json = CredentialEncryptor.Decrypt(encryptedJson);
            return JsonSerializer.Deserialize<ShipStationSettings>(json) ?? new ShipStationSettings();
        }

        public string ToEncrypted()
        {
            return CredentialEncryptor.Encrypt(JsonSerializer.Serialize(this));
        }
    }
}
