using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.EntityFrameworkCore;

namespace KLS.Data.Repositories
{
    public class BankFeedRuleSuggestionRepository : KLSRepository<BankFeedRuleSuggestion>, IBankFeedRuleSuggestionRepository
    {
        public BankFeedRuleSuggestionRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<BankFeedRuleSuggestion> GetSuggestionsWithRule()
        {
            return DbContext.BankFeedRuleSuggestions
                .Include(c => c.Rule)
                    .ThenInclude(c => c!.Action)
                .AsNoTracking();
        }

        public IQueryable<BankFeedRuleSuggestion> GetActiveSuggestions(IEnumerable<long> bankFeedTransactionIds)
        {
            var ids = bankFeedTransactionIds.ToList();
            return DbContext.BankFeedRuleSuggestions
                .Where(c => ids.Contains(c.BankFeedTransactionId)
                    && (c.SuggestionStatus == "Suggested"
                        || c.SuggestionStatus == "Conflict"
                        || c.SuggestionStatus == "MissingSetup"));
        }
    }
}
