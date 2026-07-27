using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptCreditMemo
    {
        [Key]
        public int SalesId { get; set; }

        public int SalesNumber { get; set; }

        public string? SalesDocNumber { get; set; }

        public string? PayeeName { get; set; }

        public DateOnly? ShipDate { get; set; }

        public decimal? SalesTotal { get; set; }

        public string? Instruction { get; set; }

        public string? EnteredBy { get; set; }
    }
}
