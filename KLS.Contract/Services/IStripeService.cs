using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IStripeService
    {
        Task<StripeChargeResult> ChargePayment(int payeeId, long amountCents, string paymentMethodToken, string? idempotencyKey = null);

        Task<StripeChargeResult> ChargeWithSavedMethod(int payeeId, string stripeCustomerId, string stripePaymentMethodId, long amountCents, string? idempotencyKey = null);

        Task<string> GetOrCreateStripeCustomer(int payeeId);

        Task<StripeSaveCardResult> SavePaymentMethod(int payeeId, string paymentMethodToken);
    }
}
