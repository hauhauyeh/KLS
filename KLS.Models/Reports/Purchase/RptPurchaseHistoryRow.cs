using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptPurchaseHistoryRow
    {
        [Key]
        public int PurchaseId { get; set; }

        public int PurchaseNumber { get; set; }

        public DateOnly? PurchaseDate { get; set; }

        public string? ContainerNumber { get; set; }

        public decimal? PurchaseTotal { get; set; }
    }
}
