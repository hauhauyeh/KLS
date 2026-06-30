namespace KLS.Models
{
    public class SavedMethodView
    {
        public int PaymentMethodId { get; set; }
        public string? AccountType { get; set; }
        public string? Last4 { get; set; }
        public string Gateway { get; set; }
    }
}
