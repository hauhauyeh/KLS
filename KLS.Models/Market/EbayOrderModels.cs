using System;
using System.Collections.Generic;

namespace KLS.Models
{
    public class EbayOrdersResponse
    {
        public string? href { get; set; }
        public int? total { get; set; }
        public int? limit { get; set; }
        public int? offset { get; set; }
        public string? next { get; set; }
        public string? prev { get; set; }
        public List<EbayOrder>? orders { get; set; }
    }

    public class EbayOrder
    {
        public string? orderId { get; set; }
        public string? legacyOrderId { get; set; }
        public string? creationDate { get; set; }
        public string? lastModifiedDate { get; set; }
        public string? orderFulfillmentStatus { get; set; }
        public string? orderPaymentStatus { get; set; }
        public string? sellerId { get; set; }
        public EbayBuyer? buyer { get; set; }
        public EbayPricingSummaryOrder? pricingSummary { get; set; }
        public List<EbayLineItem>? lineItems { get; set; }
        public EbayFulfillmentStartInstructions[]? fulfillmentStartInstructions { get; set; }
        public string? salesRecordReference { get; set; }
    }

    public class EbayBuyer
    {
        public string? username { get; set; }
        public EbayBuyerContact? buyerRegistrationAddress { get; set; }
        public string? taxAddress { get; set; }
    }

    public class EbayBuyerContact
    {
        public string? fullName { get; set; }
        public string? email { get; set; }
        public string? primaryPhone { get; set; }
    }

    public class EbayPricingSummaryOrder
    {
        public EbayAmount? priceSubtotal { get; set; }
        public EbayAmount? deliveryCost { get; set; }
        public EbayAmount? total { get; set; }
        public EbayAmount? tax { get; set; }
    }

    public class EbayLineItem
    {
        public string? lineItemId { get; set; }
        public string? legacyItemId { get; set; }
        public string? sku { get; set; }
        public string? title { get; set; }
        public int quantity { get; set; }
        public EbayAmount? lineItemCost { get; set; }
        public EbayAmount? total { get; set; }
        public EbayLineItemTax[]? taxes { get; set; }
        public EbayDeliveryCost? deliveryCost { get; set; }
    }

    public class EbayLineItemTax
    {
        public EbayAmount? amount { get; set; }
        public string? taxType { get; set; }
        public bool? collectedBy { get; set; }
        public string? behavior { get; set; }
    }

    public class EbayDeliveryCost
    {
        public EbayAmount? shippingCost { get; set; }
        public EbayAmount? importCharges { get; set; }
    }

    public class EbayFulfillmentStartInstructions
    {
        public EbayShippingStep? shippingStep { get; set; }
    }

    public class EbayShippingStep
    {
        public EbayShipTo? shipTo { get; set; }
    }

    public class EbayShipTo
    {
        public string? fullName { get; set; }
        public string? companyName { get; set; }
        public string? email { get; set; }
        public EbayPrimaryPhone? primaryPhone { get; set; }
        public EbayContactAddress? contactAddress { get; set; }
    }

    public class EbayPrimaryPhone
    {
        public string? phoneNumber { get; set; }
    }

    public class EbayContactAddress
    {
        public string? addressLine1 { get; set; }
        public string? addressLine2 { get; set; }
        public string? city { get; set; }
        public string? stateOrProvince { get; set; }
        public string? postalCode { get; set; }
        public string? countryCode { get; set; }
    }
}
