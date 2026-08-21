using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class BankFeedRule
    {
        public BankFeedRule()
        {
            IsActive = true;
            Priority = 100;
            CreatedAt = DateTime.UtcNow;
            Conditions = new List<BankFeedRuleCondition>();
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int BankFeedRuleId { get; set; }

        public string RuleName { get; set; } = string.Empty;

        public long? BankFeedAccountId { get; set; }

        public string Direction { get; set; } = string.Empty;

        public string MatchMode { get; set; } = string.Empty;

        public int Priority { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public virtual ICollection<BankFeedRuleCondition> Conditions { get; set; }

        public virtual BankFeedRuleAction? Action { get; set; }
    }
}
