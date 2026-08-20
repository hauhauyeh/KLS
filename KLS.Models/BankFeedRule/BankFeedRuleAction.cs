using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class BankFeedRuleAction
    {
        public BankFeedRuleAction()
        {
            AppendBankDescription = true;
            CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int BankFeedRuleActionId { get; set; }

        public int BankFeedRuleId { get; set; }

        public string ActionType { get; set; } = string.Empty;

        public int? PayeeId { get; set; }

        public int? AccountId { get; set; }

        public int? TargetAccountId { get; set; }

        public string? MemoTemplate { get; set; }

        public bool AppendBankDescription { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public virtual BankFeedRule? Rule { get; set; }
    }
}
