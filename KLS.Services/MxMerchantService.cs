using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class MxMerchantService : BaseService, IMxMerchantService
    {
        private readonly HttpClient _http;
        private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web);

        public MxMerchantService(IUnitOfWork uow, HttpClient http) : base(uow)
        {
            _http = http;
        }

        public async Task<MxCreatePaymentResponse> ChargeAsync(PaymentMethod paymentMethod, decimal amount, bool isDecrypt, CancellationToken ct = default)
        {
            if (paymentMethod == null) throw new ArgumentNullException(nameof(paymentMethod));
            if (amount <= 0m) throw new ArgumentOutOfRangeException(nameof(amount), "Amount must be greater than 0.");

            var gateway = Uow.PaymentGateways.Find(c => c.GatewayCode == "MX" && c.IsActive).FirstOrDefault();

            if (gateway == null)
                throw new Exception("No active Mx gateway configured.");

            if (string.IsNullOrWhiteSpace(gateway.MerchantId))
                throw new Exception("MX gateway MerchantId is missing.");

            // Docs show Basic auth (username/password or key/secret in Basic header)
            if (string.IsNullOrWhiteSpace(gateway.ClientKey) || string.IsNullOrWhiteSpace(gateway.AccessToken))
                throw new Exception("MX gateway credentials are missing (ClientKey/AccessToken).");

            // Base URL by environment + version
            var version = string.IsNullOrWhiteSpace(gateway.Version) ? "v3" : gateway.Version.Trim();
            var env = (gateway.Environment ?? "sandbox").Trim().ToLowerInvariant();

            var baseUrl = env switch
            {
                "production" or "prod" or "live" => $"https://api.mxmerchant.com/checkout/{version}/",
                _ => $"https://sandbox.api.mxmerchant.com/checkout/{version}/"
            };

            // Fee handling (keep your existing logic)
            var finalAmount = amount;
            if (paymentMethod.FeePercent.HasValue && paymentMethod.FeePercent.Value > 0)
            {
                var fee = amount * paymentMethod.FeePercent.Value / 100m;
                finalAmount += fee;
            }
            finalAmount = decimal.Round(finalAmount, 2);

            var isAch = paymentMethod.IsACH;

            var mxReq = new MxCreatePaymentRequest
            {
                MerchantId = gateway.MerchantId!,
                Amount = finalAmount,
                TenderType = isAch ? "ACH" : "Card",
                PaymentType = "Sale",

                // These are shown in ACH example; safe to omit for card
                AuthOnly = isAch ? false : null,
                IsAuth = isAch ? true : null,
                IsSettleFunds = isAch ? true : null,

                // Only for ACH
                EntryClass = isAch ? "CCD" : null
            };

            if (isAch)
            {
                if (string.IsNullOrWhiteSpace(paymentMethod.AccountNumber))
                    throw new InvalidOperationException("ACH account number is missing (AccountNumber).");

                if (string.IsNullOrWhiteSpace(paymentMethod.CVVOrRouting))
                    throw new InvalidOperationException("ACH routing number is missing (CVVOrRouting).");

                // Docs: bankAccount.type is "Checking"/"Savings"
                var type = string.IsNullOrWhiteSpace(paymentMethod.AccountType) ? "Checking" : paymentMethod.AccountType!.Trim();

                mxReq.BankAccount = new MxBankAccount
                {
                    Type = type,
                    RoutingNumber = isDecrypt ? Utilities.Decrypt(paymentMethod.CVVOrRouting)! : paymentMethod.CVVOrRouting!,
                    AccountNumber = isDecrypt ? Utilities.Decrypt(paymentMethod.AccountNumber)! : paymentMethod.AccountNumber!,
                    Alias = isDecrypt ? Utilities.Decrypt(paymentMethod.AccountName) : paymentMethod.AccountName,
                    Name = isDecrypt ? Utilities.Decrypt(paymentMethod.AccountName) : paymentMethod.AccountName
                };
            }
            else
            {
                if (string.IsNullOrWhiteSpace(paymentMethod.AccountNumber))
                    throw new InvalidOperationException("Card number is missing (AccountNumber).");

                if (string.IsNullOrWhiteSpace(paymentMethod.ExpMonth) || string.IsNullOrWhiteSpace(paymentMethod.ExpYear))
                    throw new InvalidOperationException("Card expiry month/year is missing.");

                mxReq.CardAccount = new MxCardAccount
                {
                    Number = isDecrypt ? Utilities.Decrypt(paymentMethod.AccountNumber)! : paymentMethod.AccountNumber!,

                    ExpiryMonth = isDecrypt ? Utilities.Decrypt(paymentMethod.ExpMonth)! : paymentMethod.ExpMonth!,

                    ExpiryYear = isDecrypt ? Utilities.Decrypt(paymentMethod.ExpYear)! : paymentMethod.ExpYear!,

                    Cvv = isDecrypt ? Utilities.Decrypt(paymentMethod.CVVOrRouting)! : paymentMethod.CVVOrRouting,

                    AvsZip = isDecrypt ? Utilities.Decrypt(paymentMethod.Zipcode!) : paymentMethod.Zipcode,

                    AvsStreet = null
                };
            }

            var url = new Uri(new Uri(baseUrl), "payment");
            using var msg = new HttpRequestMessage(HttpMethod.Post, url);

            // Basic: base64(username:password) OR base64(consumerKey:consumerSecret)
            var raw = $"{gateway.ClientKey}:{gateway.AccessToken}";
            var b64 = Convert.ToBase64String(Encoding.UTF8.GetBytes(raw));
            msg.Headers.Authorization = new AuthenticationHeaderValue("Basic", b64);

            msg.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            var json = JsonSerializer.Serialize(mxReq, JsonOpts);
            msg.Content = new StringContent(json, Encoding.UTF8, "application/json");

            using var resp = await _http.SendAsync(msg, ct);
            var body = await resp.Content.ReadAsStringAsync(ct);

            if (!resp.IsSuccessStatusCode)
            {
                var mxError = JsonSerializer.Deserialize<MxErrorResponse>(body, JsonOpts);

                if (mxError?.details != null && mxError.details.Any())
                    throw new HttpRequestException(string.Join(" | ", mxError.details));
            }

            return JsonSerializer.Deserialize<MxCreatePaymentResponse>(body, JsonOpts)
                   ?? new MxCreatePaymentResponse();
        }
    }
}
