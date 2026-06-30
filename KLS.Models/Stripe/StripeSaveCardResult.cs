namespace KLS.Models
{
    public class StripeSaveCardResult
    {
        public string StripeCustomerId { get; set; }
        public string StripePaymentMethodId { get; set; }
        public string CardBrand { get; set; }
        public string Last4 { get; set; }
    }
}
