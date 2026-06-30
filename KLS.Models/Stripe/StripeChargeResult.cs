namespace KLS.Models
{
    public class StripeChargeResult
    {
        public string PaymentIntentId { get; set; }
        public string Status { get; set; }
        public string CardBrand { get; set; }
        public string Last4 { get; set; }
        public string? ClientSecret { get; set; }
    }
}
