using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class BankFeedRuleCondition
    {
        public BankFeedRuleCondition()
        {
            CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int BankFeedRuleConditionId { get; set; }

        public int BankFeedRuleId { get; set; }

        public string ConditionType { get; set; } = string.Empty;

        public string ConditionValue { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; }

        public virtual BankFeedRule? Rule { get; set; }
    }
}
