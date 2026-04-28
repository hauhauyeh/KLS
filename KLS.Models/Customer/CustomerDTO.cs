using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CustomerDto
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

        public DateOnly? StartDate { get; set; }

        public string? Notes { get; set; }

        public int? TermId { get; set; }

        public string? GooglePlaceId { get; set; }

        public string? GoogleLat { get; set; }

        public string? GoogleLong { get; set; }

        public string? FormatAddress { get; set; }

        public string? Distance { get; set; }


        public string? Region { get; set; }

        public string? DefaultRoute { get; set; }

        public bool IsApproved { get; set; }

        public bool IsPriceShow { get; set; }

        public string? PriceShow { get; set; }

        public bool IsEditGuide { get; set; }

        public bool IsOrderingEnabled { get; set; }

        public bool IsLinkOwnShared { get; set; }

        public bool IsStatementPrint { get; set; }

        public bool IsPricePrint { get; set; }

        public bool IsStatementEmail { get; set; }

        public bool IsPriceEmail { get; set; }

        public bool IsInvoiceEmail { get; set; }

        public bool IsCSVEmail { get; set; }

        public bool IsAutoPayment { get; set; }

        public bool HasOwnList { get; set; }

        public int OwnListCount { get; set; }

        public int? SalesRepId { get; set; }

        public int? BillId { get; set; }

        public int? ShareQuoteId { get; set; }

        public bool IsShareBasePrice { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? BaseMarkup { get; set; }

        public bool IsBaseToRecentCost { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? TaxRate { get; set; }

        public string? CallSchedule { get; set; }

        public string? AdvancedScheduleType { get; set; }

        public DateOnly? AdvancedStartDate { get; set; }

        public int? AdvancedDayOfWeek { get; set; }

        public int? AdvancedWeekOfMonth { get; set; }

        public int? AdvancedDayOfMonth { get; set; }

        public DateTime? LastCallingTime { get; set; }

        public string? LastCallingStatus { get; set; }

        public DateOnly? RCExpireDate { get; set; }

        public string? RCNumber { get; set; }

        public bool IsHRTaxable { get; set; }

        public decimal? CreditLimit { get; set; }

        public string? OGSort { get; set; }

        public string? TextOrderConfirm { get; set; }

        public string? TextInvoice { get; set; }

        public string? TextStatement { get; set; }

        public string? TextPricesheet { get; set; }

        public string? TextACH { get; set; }

        public string? Market { get; set; }

        public string? Lang { get; set; }

        public decimal? MinOrder { get; set; }

        public string? SquareId { get; set; }

        public bool IsPromotionEnabled { get; set; }

        public int? ShippingCarrierId { get; set; }

        public List<UserAccountDto>? WebAccounts { get; set; }

        public bool IsOnlineRegister { get; set; }

        public string? EIN { get; set; }

        public bool IsEINVerified { get; set; }

        public DateTime? EINVerifiedAt { get; set; }

        public int? EINVerifiedBy { get; set; }

        public string? StoreType { get; set; }

        public string FullAddress
        {
            get
            {
                return string.Join(", ", new[] { Address, City, State, ZipCode }.Where(x => !string.IsNullOrWhiteSpace(x)));
            }
        }

        public string? TermName { get; set; }

        public string? SalesRepName { get; set; }

        public string? ShareQuoteName { get; set; }

        public string? BillName { get; set; }
    }
}
