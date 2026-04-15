using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AmazonOrdersResponse
    {
        public AmazonOrderList? Orders { get; set; }
    }

    public class AmazonOrderList
    {
        public List<AmazonOrder>? Orders { get; set; }
        public string? NextToken { get; set; }
    }

    public class AmazonOrder
    {
        public string? AmazonOrderId { get; set; }
        public string? OrderStatus { get; set; }
        public DateTime? PurchaseDate { get; set; }
        public AmazonMoney? OrderTotal { get; set; }
        public AmazonAddress? ShippingAddress { get; set; }
        public string? BuyerInfo { get; set; }
    }

    public class AmazonMoney
    {
        public string? Amount { get; set; }
        public string? CurrencyCode { get; set; }
    }

    public class AmazonAddress
    {
        public string? Name { get; set; }
        public string? AddressLine1 { get; set; }
        public string? AddressLine2 { get; set; }
        public string? City { get; set; }
        public string? StateOrRegion { get; set; }
        public string? PostalCode { get; set; }
        public string? CountryCode { get; set; }
    }

    public class AmazonOrderItemsResponse
    {
        [JsonPropertyName("payload")]
        public AmazonOrderItemsPayload? Payload { get; set; }

        [JsonPropertyName("AmazonOrderItems")]
        public List<AmazonOrderItem>? AmazonOrderItems { get; set; }

        [JsonPropertyName("NextToken")]
        public string? NextToken { get; set; }

        public IReadOnlyList<AmazonOrderItem> GetItems()
            => Payload?.AmazonOrderItems ?? AmazonOrderItems ?? new List<AmazonOrderItem>();

        public string? GetNextToken()
            => Payload?.NextToken ?? NextToken;
    }

    public class AmazonOrderItemsPayload
    {
        public List<AmazonOrderItem>? AmazonOrderItems { get; set; }
        public string? NextToken { get; set; }
    }

    public class AmazonOrderItem
    {
        public string? ASIN { get; set; }
        public string? SellerSKU { get; set; }
        public string? OrderItemId { get; set; }
        public string? Title { get; set; }
        public int? QuantityOrdered { get; set; }
        public AmazonMoney? ItemPrice { get; set; }
        public AmazonMoney? ItemTax { get; set; }
        public AmazonMoney? PromotionDiscount { get; set; }
    }
}
