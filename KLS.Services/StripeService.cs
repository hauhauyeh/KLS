using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Stripe;

namespace KLS.Services
{
    public class StripeService : BaseService, IStripeService
    {
        private string _apiKey;

        public StripeService(IUnitOfWork uow) : base(uow) { }

        public async Task<StripeChargeResult> ChargePayment(int payeeId, long amountCents, string paymentMethodToken, string? idempotencyKey = null)
        {
            LoadApiKey();

            var options = new PaymentIntentCreateOptions
            {
                Amount = amountCents,
                Currency = "usd",
                PaymentMethod = paymentMethodToken,
                Confirm = true,
                Expand = new List<string> { "latest_charge" },
                Metadata = new Dictionary<string, string> { { "payeeId", payeeId.ToString() } }
            };

            var requestOptions = new RequestOptions
            {
                ApiKey = _apiKey,
                IdempotencyKey = idempotencyKey ?? Guid.NewGuid().ToString()
            };

            var service = new PaymentIntentService();
            var intent = await service.CreateAsync(options, requestOptions);

            return MapResult(intent);
        }

        public async Task<StripeChargeResult> ChargeWithSavedMethod(int payeeId, string stripeCustomerId, string stripePaymentMethodId, long amountCents, string? idempotencyKey = null)
        {
            LoadApiKey();

            var options = new PaymentIntentCreateOptions
            {
                Amount = amountCents,
                Currency = "usd",
                Customer = stripeCustomerId,
                PaymentMethod = stripePaymentMethodId,
                Confirm = true,
                OffSession = false,
                Expand = new List<string> { "latest_charge" },
                Metadata = new Dictionary<string, string> { { "payeeId", payeeId.ToString() } }
            };

            var requestOptions = new RequestOptions
            {
                ApiKey = _apiKey,
                IdempotencyKey = idempotencyKey ?? Guid.NewGuid().ToString()
            };

            var service = new PaymentIntentService();
            var intent = await service.CreateAsync(options, requestOptions);

            return MapResult(intent);
        }

        public async Task<string> GetOrCreateStripeCustomer(int payeeId)
        {
            LoadApiKey();

            var customer = Uow.Customers.GetById(payeeId);
            if (customer == null)
                throw new Exception("Customer not found.");

            if (!string.IsNullOrEmpty(customer.StripeId))
                return customer.StripeId;

            var payee = Uow.Payees.GetById(payeeId);

            var options = new CustomerCreateOptions
            {
                Name = payee.PayeeName,
                Email = payee.Email,
                Phone = payee.Phone1,
                Metadata = new Dictionary<string, string> { { "payeeId", payeeId.ToString() } }
            };

            var requestOptions = new RequestOptions { ApiKey = _apiKey };

            var stripeService = new Stripe.CustomerService();
            var stripeCustomer = await stripeService.CreateAsync(options, requestOptions);

            customer.StripeId = stripeCustomer.Id;
            Uow.Customers.Update(customer);
            Uow.Commit();

            return stripeCustomer.Id;
        }

        public async Task<StripeSaveCardResult> SavePaymentMethod(int payeeId, string paymentMethodToken)
        {
            LoadApiKey();

            var stripeCustomerId = await GetOrCreateStripeCustomer(payeeId);

            var attachOptions = new PaymentMethodAttachOptions { Customer = stripeCustomerId };
            var requestOptions = new RequestOptions { ApiKey = _apiKey };

            var pmService = new Stripe.PaymentMethodService();
            var pm = await pmService.AttachAsync(paymentMethodToken, attachOptions, requestOptions);

            return new StripeSaveCardResult
            {
                StripeCustomerId = stripeCustomerId,
                StripePaymentMethodId = pm.Id,
                CardBrand = pm.Card?.Brand,
                Last4 = pm.Card?.Last4
            };
        }

        private void LoadApiKey()
        {
            if (_apiKey != null) return;

            var gateway = Uow.PaymentGateways.Find(x => x.GatewayCode == "STRIPE" && x.IsActive).FirstOrDefault();

            if (gateway == null)
                throw new Exception("No active Stripe gateway configured.");

            if (string.IsNullOrWhiteSpace(gateway.AccessToken))
                throw new Exception("Stripe secret key is missing for the active gateway.");

            _apiKey = gateway.AccessToken;
        }

        private static StripeChargeResult MapResult(PaymentIntent intent)
        {
            return new StripeChargeResult
            {
                PaymentIntentId = intent.Id,
                Status = intent.Status,
                CardBrand = intent.LatestCharge?.PaymentMethodDetails?.Card?.Brand,
                Last4 = intent.LatestCharge?.PaymentMethodDetails?.Card?.Last4,
                ClientSecret = intent.ClientSecret
            };
        }
    }
}
