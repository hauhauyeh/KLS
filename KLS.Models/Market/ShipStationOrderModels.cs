using System;
using System.Collections.Generic;

namespace KLS.Models
{
    public class ShipStationOrdersResponse
    {
        public List<ShipStationOrder>? orders { get; set; }
        public int total { get; set; }
        public int page { get; set; }
        public int pages { get; set; }
    }

    public class ShipStationOrder
    {
        public int orderId { get; set; }
        public string? orderNumber { get; set; }
        public string? orderKey { get; set; }
        public DateTime? orderDate { get; set; }
        public DateTime? createDate { get; set; }
        public DateTime? modifyDate { get; set; }
        public string? orderStatus { get; set; }
        public int? customerId { get; set; }
        public string? customerUsername { get; set; }
        public string? customerEmail { get; set; }
        public decimal? orderTotal { get; set; }
        public decimal? amountPaid { get; set; }
        public decimal? taxAmount { get; set; }
        public decimal? shippingAmount { get; set; }
        public ShipStationAddress? shipTo { get; set; }
        public ShipStationAddress? billTo { get; set; }
        public List<ShipStationOrderItem>? items { get; set; }
        public string? customerNotes { get; set; }
        public string? internalNotes { get; set; }
        public ShipStationAdvancedOptions? advancedOptions { get; set; }
    }

    public class ShipStationAddress
    {
        public string? name { get; set; }
        public string? company { get; set; }
        public string? street1 { get; set; }
        public string? street2 { get; set; }
        public string? street3 { get; set; }
        public string? city { get; set; }
        public string? state { get; set; }
        public string? postalCode { get; set; }
        public string? country { get; set; }
        public string? phone { get; set; }
    }

    public class ShipStationOrderItem
    {
        public long orderItemId { get; set; }
        public int? productId { get; set; }
        public string? lineItemKey { get; set; }
        public string? sku { get; set; }
        public string? name { get; set; }
        public decimal quantity { get; set; }
        public decimal? unitPrice { get; set; }
        public decimal? taxAmount { get; set; }
        public decimal? shippingAmount { get; set; }
        public string? imageUrl { get; set; }
        public string? upc { get; set; }
    }

    public class ShipStationAdvancedOptions
    {
        public int? storeId { get; set; }
        public string? source { get; set; }
        public int? warehouseId { get; set; }
    }

    public class ShipStationProduct
    {
        public int productId { get; set; }
        public string? sku { get; set; }
        public string? name { get; set; }
        public decimal? price { get; set; }
        public decimal? defaultCost { get; set; }
        public decimal? length { get; set; }
        public decimal? width { get; set; }
        public decimal? height { get; set; }
        public decimal? weightOz { get; set; }
        public string? internalNotes { get; set; }
        public string? fulfillmentSku { get; set; }
        public bool? active { get; set; }
        public object? productCategory { get; set; }
        public object? productType { get; set; }
        public string? warehouseLocation { get; set; }
        public string? defaultCarrierCode { get; set; }
        public string? defaultServiceCode { get; set; }
        public string? defaultPackageCode { get; set; }
        public string? defaultIntlCarrierCode { get; set; }
        public string? defaultIntlServiceCode { get; set; }
        public string? defaultIntlPackageCode { get; set; }
        public string? defaultConfirmation { get; set; }
        public string? defaultIntlConfirmation { get; set; }
        public string? customsDescription { get; set; }
        public decimal? customsValue { get; set; }
        public string? customsTariffNo { get; set; }
        public string? customsCountryCode { get; set; }
        public bool? noCustoms { get; set; }
        public List<object>? tags { get; set; }
        public string? upc { get; set; }
        public string? thumbnailURL { get; set; }
        public List<object>? aliases { get; set; }
    }
}
