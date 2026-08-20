using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IBankFeedRuleService
    {
        PagingResponse<BankFeedRuleDto> GetPagedList(BankFeedRuleListReq req);

        BankFeedRuleDto? GetById(int bankFeedRuleId);

        BankFeedRuleDto Save(BankFeedRuleSaveReq req);

        void Deactivate(int bankFeedRuleId);

        void Delete(int bankFeedRuleId);

        BankFeedRuleRecalculateRes Recalculate(BankFeedRuleRecalculateReq req);

        List<BankFeedRuleSuggestionDto> GetSuggestions(long bankFeedTransactionId);
    }
}
