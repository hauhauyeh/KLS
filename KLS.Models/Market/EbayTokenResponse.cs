namespace KLS.Models
{
    public class EbayTokenResponse
    {
        public string access_token { get; set; } = string.Empty;
        public string token_type { get; set; } = string.Empty;
        public int expires_in { get; set; }
        public string? refresh_token { get; set; }
        public int? refresh_token_expires_in { get; set; }
    }
}
