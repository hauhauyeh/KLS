using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class POList
    {
        [Key]
        public int PurchaseId { get; set; }

        public int PurchaseNumber { get; set; }

        public string? PayeeName { get; set; }

        public int? StageId { get; set; }

        public string? StageName { get; set; }

        public int? PayeeId { get; set; }

        public DateOnly? PurchaseDate { get; set; }

        public DateOnly? EnterDate { get; set; }

        public DateOnly? ArrivalDate { get; set; }

        public DateOnly? InvoiceDate { get; set; }

        public string? VendorDocNumber { get; set; }

        public string? FactorPO { get; set; }

        public string? ContainerNumber { get; set; }

        public decimal? OrderTotal { get; set; }

        public decimal? VendorTotal { get; set; }

        public decimal? PurchaseTotal { get; set; }

        public decimal? AmountDue { get; set; }

        public string? Notes { get; set; }

        public bool IsLocked { get; set; }

        public bool IsNormalPurchase { get; set; }

        public bool IsPayNow { get; set; }

        public bool IsFreightOnly { get; set; }

        public decimal? FreightTotal { get; set; }

        public int? PalletCount { get; set; }

        public decimal? ImportCommission { get; set; }

        public decimal? CustomDutyTotal { get; set; }

        public int? PaymentStatusId { get; set; }

        public string? PaymentStatusName { get; set; }

        public bool IsDropShip { get; set; }

        public int? DropShipSalesId { get; set; }

        public int? DropShipSalesNumber { get; set; }
        public string? DropShipChainLabel { get; set; }
        public int? DropShipSalesStageId { get; set; }
        public string? DropShipSalesCustPONumber { get; set; }
        public string? DropShipSalesCustomerName { get; set; }

        public bool IsBillStage => StageId == 6;

        [NotMapped]
        public bool IsPdfExist { get; set; }
    }
}
