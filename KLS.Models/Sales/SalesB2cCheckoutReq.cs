namespace KLS.Models
{
    public class SalesB2cCheckoutReq
    {
        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public bool IsPickUp { get; set; }

        public string? Instruction { get; set; }

        public string? Email { get; set; }

        public string? Phone { get; set; }

        public int? PaymentMethodId { get; set; }

        public decimal? CCFeePercent { get; set; }

        public PaymentMethod? PaymentMethod { get; set; }

        public string ClientRequestKey { get; set; } = string.Empty;
    }
}
