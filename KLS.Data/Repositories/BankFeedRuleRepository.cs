using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.EntityFrameworkCore;

namespace KLS.Data.Repositories
{
    public class BankFeedRuleRepository : KLSRepository<BankFeedRule>, IBankFeedRuleRepository
    {
        public BankFeedRuleRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<BankFeedRule> GetRulesWithChildren()
        {
            return DbContext.BankFeedRules
                .Include(c => c.Conditions)
                .Include(c => c.Action)
                .AsNoTracking();
        }

        public BankFeedRule? GetRuleWithChildren(int bankFeedRuleId)
        {
            return DbContext.BankFeedRules
                .Include(c => c.Conditions)
                .Include(c => c.Action)
                .FirstOrDefault(c => c.BankFeedRuleId == bankFeedRuleId);
        }

        public void RemoveRuleChildren(BankFeedRule rule)
        {
            if (rule.Action != null)
            {
                DbContext.BankFeedRuleActions.Remove(rule.Action);
            }

            DbContext.BankFeedRuleConditions.RemoveRange(rule.Conditions);
        }

        public void RemoveRule(BankFeedRule rule)
        {
            RemoveRuleChildren(rule);
            DbContext.BankFeedRules.Remove(rule);
        }
    }
}
