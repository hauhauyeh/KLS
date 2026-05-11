namespace KLS.Models
{
    public class WebLoginResult
    {
        public bool Success { get; set; }
        public string? ErrorMessage { get; set; }

        public string? Token { get; set; }
        public string? RefreshToken { get; set; }

        public string? Username { get; set; }
        public int UserId { get; set; }
        public bool IsOwner { get; set; }
        public bool IsAdmin { get; set; }

        public bool RequireEmailVerification { get; set; }

        public string PriceShow { get; set; } = "Hide";
        public bool IsEditGuide { get; set; }
        public bool IsPromotionEnabled { get; set; }
    }
}
