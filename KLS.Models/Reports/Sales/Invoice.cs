using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class Invoice
    {
        [Key]
        public int SalesId { get; set; }

        public int SalesNumber { get; set; }
        public string? SalesDocNumber { get; set; }
        public string? DocType { get; set; }
        public int? ParentSalesNumber { get; set; }

        public bool IsDropShip { get; set; }

        public int ShipId { get; set; }

        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public int? RouteOrder { get; set; }

        public decimal? SubTotal { get; set; }

        public decimal? TaxTotal { get; set; }

        public decimal? SalesTotal { get; set; }

        public string? Instruction { get; set; }

        public string? ShipName { get; set; }

        public string? ShipAddress { get; set; }

        public string? ShipCity { get; set; }

        public string? ShipState { get; set; }

        public string? ShipZipCode { get; set; }

        public string? ShipPhone1 { get; set; }

        public string? BillName { get; set; }

        public string? BillAddress { get; set; }

        public string? BillCity { get; set; }

        public string? BillState { get; set; }

        public string? BillZipCode { get; set; }

        public string? BillPhone1 { get; set; }

        public string? TermName { get; set; }

        public string? CustPONumber { get; set; }

        public string? DropShipPurchaseFactorPO { get; set; }

        public string? DropShipPurchaseVendorDocNumber { get; set; }

        public string? DropShipPurchaseContainerNumber { get; set; }

        public string? DropShipChainLabel { get; set; }

        public bool IsPastDue { get; set; }

        public decimal? PayeePastDue { get; set; }

        public string? DriverName { get; set; }

        public string? SalesRepName { get; set; }

        public string? TruckNumber { get; set; }

        public bool IsLoadSeparate { get; set; }

        public int? ShippingCarrierId { get; set; }

        public int RouteDrops { get; set; }
    }
}
