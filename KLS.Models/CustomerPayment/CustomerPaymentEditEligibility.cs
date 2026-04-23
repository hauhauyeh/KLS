namespace KLS.Models
{
    public class CustomerPaymentEditEligibility
    {
        public bool CanEdit { get; set; }

        public bool IsReadOnly { get; set; }

        public string? Reason { get; set; }
    }
}
