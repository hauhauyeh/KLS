using KLS.Models;

namespace KLS.Contract.Interfaces
{
    public interface IBankFeedRuleSuggestionRepository : IRepository<BankFeedRuleSuggestion>
    {
        IQueryable<BankFeedRuleSuggestion> GetSuggestionsWithRule();

        IQueryable<BankFeedRuleSuggestion> GetActiveSuggestions(IEnumerable<long> bankFeedTransactionIds);
    }
}
