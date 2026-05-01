using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class OrderWebList
    {
        [Key]
        public int SalesId { get; set; }

        public int SalesNumber { get; set; }

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


        [NotMapped]
        public bool IsPdfExist { get; set; }
    }
}
