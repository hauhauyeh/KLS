using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Net;
using System.Reflection.Emit;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Customer
    {
        [Key]
        public int PayeeId { get; set; }

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
        
        public int? SalesRepId { get; set; }
        
        public int? BillId { get; set; }
        
        //public string? DefaultBasePriceId { get; set; }
        
        public int? ShareQuoteId { get; set; }

        public bool IsShareBasePrice { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? TaxRate { get; set; }
        
        public string? CallSchedule { get; set; }
        
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

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? BaseMarkup { get; set; }
        
        public int? ShippingCarrierId { get; set; }
        
        public bool IsOnlineRegister { get; set; }
    }
}
