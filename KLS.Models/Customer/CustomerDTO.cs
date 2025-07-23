using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CustomerDTO
    {
        [Key]
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string? PayeeType { get; set; }

        public string? GoogleAddress { get; set; }

        public string? GoogleMapLink { get; set; }

        public string? Address { get; set; }

        public string? City { get; set; }

        public string? State { get; set; }

        public string? ZipCode { get; set; }

        public string? Country { get; set; }

        public string? PhoneDesc1 { get; set; }

        public string? Phone1 { get; set; }

        public string? PhoneDesc2 { get; set; }

        public string? Phone2 { get; set; }

        public string? PhoneDesc3 { get; set; }

        public string? Phone3 { get; set; }

        public string? PhoneDesc4 { get; set; }

        public string? Phone4 { get; set; }

        public string? PhoneDesc5 { get; set; }

        public string? Phone5 { get; set; }

        public string? PhoneDesc6 { get; set; }

        public string? Phone6 { get; set; }

        public string? Email { get; set; }

        public string? EmailInvoice { get; set; }

        public string? EmailStmt { get; set; }

        public string? EmailPricesheet { get; set; }

        public string? EmailACH { get; set; }

        public bool IsClosed { get; set; }

        public bool IsDelinquent { get; set; }

        public int? GracePeriod { get; set; }

        public DateTime? StartDate { get; set; }

        public string? Notes { get; set; }

        public string? TermName { get; set; }


        public string? Region { get; set; }

        public string? DefRoute { get; set; }

        public bool IsApproved { get; set; }

        public bool IsPriceShow { get; set; }

        public string? PriceShow { get; set; }

        public bool IsEditGuide { get; set; }

        public bool IsOrderingEnabled { get; set; }

        public bool IsLinkOwnShared { get; set; }

        public bool IsStmtPrint { get; set; }

        public bool IsPricePrint { get; set; }

        public bool IsStmtEmail { get; set; }

        public bool IsPriceEmail { get; set; }

        public bool IsInvoiceEmail { get; set; }

        public bool IsCSVEmail { get; set; }

        public bool IsAutoPayment { get; set; }

        public bool HasOwnList { get; set; }

        public int? SalesRep { get; set; }

        public int? BillId { get; set; }

        public string? DefBasePriceId { get; set; }

        public int? DefQuoteId { get; set; }

        public decimal? TaxRate { get; set; }

        public string? CallSchedule { get; set; }

        public DateOnly? LastOrderDate { get; set; }

        public DateOnly? FirstDueDate { get; set; }

        public DateTime? LastCallingTime { get; set; }

        public string? LastCallingStatus { get; set; }

        public DateOnly? RCExpireDate { get; set; }

        public string? RCNumber { get; set; }

        public bool HRTaxable { get; set; }

        public decimal? CreditLimit { get; set; }

        public string? OGSort { get; set; }

        public string? TextOrderConfirm { get; set; }

        public string? TextInvoice { get; set; }

        public string? TextStmt { get; set; }

        public string? TextPricesheet { get; set; }

        public string? TextACH { get; set; }

        public string? Market { get; set; }

        public string? Lang { get; set; }

        public int? AvgPayDay { get; set; }

        public string? Lat1 { get; set; }

        public string? Long1 { get; set; }

        public decimal? MinOrder { get; set; }

        public string? SquareId { get; set; }

        public bool ShowPromotion { get; set; }

        public string? FormatAddress { get; set; }

        public string? PlaceId { get; set; }

        public string? Distance { get; set; }

        public decimal? Markup { get; set; }

        public int? ShippingCarrierId { get; set; }

        public bool IsOnlineRegister { get; set; }
    }
}
