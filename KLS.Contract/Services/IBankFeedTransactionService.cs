using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IBankFeedTransactionService
    {
        BankFeedUploadPreviewRes UploadPreview(BankFeedUploadPreviewReq req);

        int Import(BankFeedImportReq req);

        PagingResponse<BankFeedTransactionList> GetList(BankFeedListReq req);

        List<BankFeedMatchCandidate> GetMatchCandidates(long bankFeedTransactionId);

        void Match(BankFeedMatchReq req);

        void Unmatch(BankFeedMatchReq req);

        void Exclude(BankFeedExcludeReq req);

        void Delete(long bankFeedTransactionId);
    }
}
