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

        BankFeedRuleRecalculateRes RecalculatePending(BankFeedRuleRecalculatePendingReq req);

        List<BankFeedRuleSuggestionDto> GetSuggestions(long bankFeedTransactionId);

        BankFeedRuleApplyRes Apply(long bankFeedRuleSuggestionId);

        BankFeedRuleBulkApplyRes ApplyBulk(BankFeedBulkActionReq req);
    }
}
