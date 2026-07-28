using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    /// <summary>
    /// One candidate open vendor bill for a pending money-out bank feed row.
    /// Projected from BankFeed_GetOpenBills.
    /// </summary>
    public class BankFeedOpenBill
    {
        [Key]
        public int PurchaseId { get; set; }

        public int PurchaseNumber { get; set; }

        public int PayeeId { get; set; }

        public string? VendorName { get; set; }

        public string? VendorDocNumber { get; set; }

        public DateOnly PurchaseDate { get; set; }

        public DateOnly? DueDate { get; set; }

        public int? Aging { get; set; }

        public decimal PurchaseTotal { get; set; }

        /// <summary>The open balance. This is what an apply amount is measured against.</summary>
        public decimal AmountDue { get; set; }

        /// <summary>
        /// Oldest-first fill from what is left of the bank amount. A UI convenience only —
        /// the create procedure never trusts it and validates what the client actually sends.
        /// </summary>
        public decimal SuggestedApplyAmount { get; set; }
    }
}
