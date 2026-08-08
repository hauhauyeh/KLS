using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Reflection.Metadata.Ecma335;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesList
    {
        [Key]
        public int SalesId { get; set; }

        public int SalesNumber { get; set; }
        public string? SalesDocNumber { get; set; }
        public int? ParentSalesNumber { get; set; }
        public string? DocType { get; set; }

        public DateTime? SalesDate { get; set; }

        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public int? ShipId { get; set; }

        public decimal? SubTotal { get; set; }

        public decimal? TaxTotal { get; set; }

        public decimal? SalesTotal { get; set; }

        public string? Instruction { get; set; }

        public decimal? AmountDue { get; set; }

        public string? CustPONumber { get; set; }

        public int? RouteOrder { get; set; }

        public bool IsLocked { get; set; }

        public bool IsLoadSeparate { get; set; }

        public string? TruckNumber { get; set; }

        public string? DriverName { get; set; }

        public string? PayeeName { get; set; }

        public string? City { get; set; }

        public int? StageId { get; set; }

        public string? StageName { get; set; }

        public int? PaymentStatusId { get; set; }

        public string? PaymentStatusName { get; set; }

        public int? ShippingCarrierId { get; set; }

        public string? ShippingCarrierName { get; set; }

        public string? TermName { get; set; }

        public bool IsCreditHold { get; set; }

        public decimal? PayeePastDue { get; set; }

        public decimal? Balance { get; set; }

        public int? MaxInvoiceAgingDays { get; set; }

        public bool IsPastDue { get; set; }

        public bool IsDropShip { get; set; }

        // 2026-07-13: linked drop-ship purchase (PO/Bill) ref for the SO -> PO/Bill badge.
        public int? DropShipPurchaseId { get; set; }
        public int? DropShipPurchaseNumber { get; set; }
        public string? DropShipPurchaseFactorPO { get; set; }
        public string? DropShipPurchaseVendorDocNumber { get; set; }
        public string? DropShipPurchaseContainerNumber { get; set; }
        public string? DropShipChainLabel { get; set; }
        public int? DropShipPurchaseStageId { get; set; }
        public int? DropShipPurchasePayeeId { get; set; }
        public bool HasBackorderDropShip { get; set; }

        [NotMapped]
        public bool IsPdfExist { get; set; }
    }
}
