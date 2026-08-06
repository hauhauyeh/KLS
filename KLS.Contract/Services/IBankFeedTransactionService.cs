using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IBankFeedTransactionService
    {
        BankFeedUploadPreviewRes UploadPreview(BankFeedUploadPreviewReq req);

        int Import(BankFeedImportReq req);

        PagingResponse<BankFeedTransactionList> GetList(BankFeedListReq req);

        List<BankFeedMatchCandidate> GetMatchCandidates(long bankFeedTransactionId);

        PagingResponse<BankFeedOpenBill> GetOpenBills(BankFeedOpenBillsReq req);

        PagingResponse<BankFeedUndepositedPayment> GetUndepositedPayments(BankFeedUndepositedPaymentsReq req);

        int CreateVendorPayment(BankFeedCreateVendorPaymentReq req);

        int CreateDeposit(BankFeedCreateDepositReq req);

        BankFeedChargePayee? GetLastChargePayee();

        void ReverseGenerated(BankFeedReverseReq req);

        void Match(List<BankFeedMatchReq> reqs);

        int Unmatch(BankFeedBulkActionReq req);

        int Exclude(BankFeedBulkExcludeReq req);

        int UnExclude(BankFeedBulkActionReq req);

        int Delete(BankFeedBulkActionReq req);
    }
}
