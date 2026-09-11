using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptSalesSummary
    {
        [Key]
        public DateOnly PeriodStart { get; set; }

        public DateOnly? PeriodEnd { get; set; }

        public string? PeriodLabel { get; set; }

        public string? Grain { get; set; }

        public decimal? CurrentTotal { get; set; }

        public decimal? PriorTotal { get; set; }

        public decimal? DeltaAmount { get; set; }

        public decimal? DeltaPercent { get; set; }

        public int? CurrentTx { get; set; }

        public int? PriorTx { get; set; }

        public decimal? OrderTotal { get; set; }

        public decimal? TransitTotal { get; set; }

        public int? OrderTx { get; set; }

        public int? TransitTx { get; set; }
    }
}
