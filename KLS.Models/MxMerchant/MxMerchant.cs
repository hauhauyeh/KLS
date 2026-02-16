using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace KLS.Models
{
    public sealed class MxCardAccount
    {
        [JsonPropertyName("number")]
        public required string Number { get; init; }

        [JsonPropertyName("expiryMonth")]
        public required string ExpiryMonth { get; init; }

        [JsonPropertyName("expiryYear")]
        public required string ExpiryYear { get; init; }

        [JsonPropertyName("cvv")]
        public string? Cvv { get; init; }

        // MX docs use avsZip / avsStreet
        [JsonPropertyName("avsZip")]
        public string? AvsZip { get; init; }

        [JsonPropertyName("avsStreet")]
        public string? AvsStreet { get; init; }
    }

    public sealed class MxBankAccount
    {
        // "Checking" / "Savings" as shown in docs
        [JsonPropertyName("type")]
        public required string Type { get; init; }

        [JsonPropertyName("routingNumber")]
        public required string RoutingNumber { get; init; }

        [JsonPropertyName("accountNumber")]
        public required string AccountNumber { get; init; }

        // Optional in docs, but present in example
        [JsonPropertyName("alias")]
        public string? Alias { get; init; }

        [JsonPropertyName("name")]
        public string? Name { get; init; }
    }

    public sealed class MxCreatePaymentRequest
    {
        [JsonPropertyName("merchantId")]
        public required string MerchantId { get; init; }

        [JsonPropertyName("tenderType")]
        public required string TenderType { get; init; } // "Card" / "ACH"

        [JsonPropertyName("paymentType")]
        public string PaymentType { get; init; } = "Sale";

        [JsonPropertyName("amount")]
        public required decimal Amount { get; init; }

        // ACH-related controls shown in ACH example
        [JsonPropertyName("authOnly")]
        public bool? AuthOnly { get; init; }

        [JsonPropertyName("isAuth")]
        public bool? IsAuth { get; init; }

        [JsonPropertyName("isSettleFunds")]
        public bool? IsSettleFunds { get; init; }

        // Only send for ACH
        [JsonPropertyName("entryClass")]
        public string? EntryClass { get; init; } // "CCD" / "PPD" / "TEL" / "WEB"

        [JsonPropertyName("cardAccount")]
        public MxCardAccount? CardAccount { get; set; }

        // ACH uses "bankAccount" per docs
        [JsonPropertyName("bankAccount")]
        public MxBankAccount? BankAccount { get; set; }
    }

    public sealed class MxCreatePaymentResponse
    {
        [JsonExtensionData]
        public Dictionary<string, object?> Extra { get; set; } = new();
    }

    public sealed class MxErrorResponse
    {
        public string? errorCode { get; set; }
        public string? message { get; set; }
        public List<string>? details { get; set; }
        public string? responseCode { get; set; }
    }
}
