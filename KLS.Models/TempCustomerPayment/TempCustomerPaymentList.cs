using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempCustomerPaymentList
    {
        [Key]
        public int TempCPId { get; set; }

        public int PayeeId { get; set; }

        public int CustomerPaymentId { get; set; }

        public int SalesId { get; set; }

        public string? SourceType { get; set; }

        public int? SourceId { get; set; }

        public bool IsSelected { get; set; }

        public string? DocNumber { get; set; }

        public DateOnly? DocDate { get; set; }

        public string? Description { get; set; }

        public decimal? OriginalAmount { get; set; }

        public decimal? OpenBalanceBefore { get; set; }

        public string? TermName { get; set; }

        public decimal? DiscountPercent { get; set; }

        public decimal? DiscountAlreadyTaken { get; set; }

        public DateOnly? DiscountDate { get; set; }

        public int? DueDays { get; set; }

        public decimal? AmountDue { get; set; }

        public decimal? PaymentApplied { get; set; }

        public decimal? DiscountApplied { get; set; }

        public decimal? PaymentDiscount { get; set; }

        public decimal? ShortDiscount { get; set; }

        public decimal? OtherDiscount { get; set; }

        public bool IsApplied { get; set; }

        public int SalesNumber { get; set; }

        public DateOnly ShipDate { get; set; }

        public decimal? SalesTotal { get; set; }

        public string? ShipName { get; set; }

        public string? BillName { get; set; }

        public bool IsCCFee { get; set; }

        public decimal? DiscountAvailable
        {
            get
            {
                var original = OriginalAmount ?? SalesTotal ?? 0;
                var percent = DiscountPercent ?? 0;
                var taken = DiscountAlreadyTaken ?? 0;
                var maxAmount = Math.Round(original * percent / 100, 2);
                return Math.Max(0, maxAmount - taken);
            }
        }

        public decimal? OpenBalanceAfter
        {
            get
            {
                var before = OpenBalanceBefore ?? AmountDue ?? 0;
                return before - (PaymentApplied ?? 0) - (DiscountApplied ?? 0);
            }
        }

        public decimal? LeaveShort
        {
            get
            {
                return IsApplied ? (AmountDue - PaymentApplied - DiscountApplied) : 0;
            }
        }

        [NotMapped]
        public bool IsPdfExist { get; set; }
    }
}
