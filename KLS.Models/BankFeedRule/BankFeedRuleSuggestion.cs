using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class BankFeedRuleSuggestion
    {
        public BankFeedRuleSuggestion()
        {
            SuggestionStatus = "Suggested";
            CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long BankFeedRuleSuggestionId { get; set; }

        public long BankFeedTransactionId { get; set; }

        public int BankFeedRuleId { get; set; }

        public string SuggestionStatus { get; set; } = string.Empty;

        public bool IsPreferred { get; set; }

        public int Score { get; set; }

        public string? Reason { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? AppliedAt { get; set; }

        public int? AppliedBy { get; set; }

        public DateTime? DismissedAt { get; set; }

        public int? DismissedBy { get; set; }

        public virtual BankFeedRule? Rule { get; set; }
    }
}
