using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace KLS.Models
{
    public class WalmartOrdersResponse
    {
        public List<WalmartOrder>? Orders { get; set; }
        public WalmartOrderListWrapper? List { get; set; }
        public string? NextCursor { get; set; }

        public IReadOnlyList<WalmartOrder> GetOrders()
        {
            return Orders ?? List?.Elements?.Order ?? new List<WalmartOrder>();
        }

        public string? GetNextCursor()
        {
            return NextCursor ?? List?.Meta?.NextCursor;
        }
    }

    public class WalmartOrderListWrapper
    {
        public WalmartOrderElements? Elements { get; set; }
        public WalmartOrderMeta? Meta { get; set; }
    }

    public class WalmartOrderElements
    {
        [JsonPropertyName("order")]
        public List<WalmartOrder>? Order { get; set; }
    }

    public class WalmartOrderMeta
    {
        public string? NextCursor { get; set; }
    }

    public class WalmartOrder
    {
        public string? PurchaseOrderId { get; set; }
        public string? CustomerOrderId { get; set; }
        public string? Status { get; set; }
        public DateTime? OrderDate { get; set; }
        public string? CustomerEmailId { get; set; }
        public WalmartOrderShippingInfo? ShippingInfo { get; set; }
        public decimal? OrderTotal { get; set; }
        public WalmartOrderLines? OrderLines { get; set; }

        public IReadOnlyList<WalmartOrderLine> GetOrderLines()
        {
            return OrderLines?.OrderLine ?? new List<WalmartOrderLine>();
        }
    }

    public class WalmartOrderLines
    {
        [JsonPropertyName("orderLine")]
        public List<WalmartOrderLine>? OrderLine { get; set; }
    }

    public class WalmartOrderLine
    {
        public string? LineNumber { get; set; }
        public WalmartOrderItemInfo? Item { get; set; }
        public WalmartOrderLineQuantity? OrderLineQuantity { get; set; }
        public WalmartOrderCharges? Charges { get; set; }
    }

    public class WalmartOrderItemInfo
    {
        public string? Sku { get; set; }
        public string? ProductName { get; set; }
    }

    public class WalmartOrderLineQuantity
    {
        public decimal? Amount { get; set; }
        public string? UnitOfMeasurement { get; set; }
    }

    public class WalmartOrderCharges
    {
        public WalmartOrderCharge? Charge { get; set; }
    }

    public class WalmartOrderCharge
    {
        public WalmartMoney? ChargeAmount { get; set; }
        public WalmartMoney? Tax { get; set; }
    }

    public class WalmartMoney
    {
        public decimal? Amount { get; set; }
        public string? Currency { get; set; }
    }

    public class WalmartOrderShippingInfo
    {
        public string? Phone { get; set; }
        public WalmartOrderPostalAddress? PostalAddress { get; set; }
    }

    public class WalmartOrderPostalAddress
    {
        public string? Name { get; set; }
        public string? Address1 { get; set; }
        public string? Address2 { get; set; }
        public string? City { get; set; }
        public string? State { get; set; }
        public string? PostalCode { get; set; }
        public string? Country { get; set; }
    }
}
