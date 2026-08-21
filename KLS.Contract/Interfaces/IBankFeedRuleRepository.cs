using KLS.Models;

namespace KLS.Contract.Interfaces
{
    public interface IBankFeedRuleRepository : IRepository<BankFeedRule>
    {
        IQueryable<BankFeedRule> GetRulesWithChildren();

        BankFeedRule? GetRuleWithChildren(int bankFeedRuleId);

        void RemoveRuleChildren(BankFeedRule rule);

        void RemoveRule(BankFeedRule rule);
    }
}
