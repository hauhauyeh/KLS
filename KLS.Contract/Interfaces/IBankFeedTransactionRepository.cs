using KLS.Models;

namespace KLS.Contract.Interfaces
{
    public interface IBankFeedTransactionRepository : IRepository<BankFeedTransaction>
    {
        BankFeedTransaction? GetByLongId(long bankFeedTransactionId);

        IQueryable<BankFeedTransactionList> GetPagedList(BankFeedListReq req);

        int CountList(BankFeedListReq req);

        IQueryable<BankFeedMatchCandidate> GetMatchCandidates(long bankFeedTransactionId);

        IQueryable<BankFeedOpenBill> GetOpenBills(BankFeedOpenBillsReq req);

        int CountOpenBills(BankFeedOpenBillsReq req);

        int CreateVendorPayment(BankFeedCreateVendorPaymentReq req, string linesJson,
                                string? resolvingLinesJson, int empId);

        void MatchTx(long bankFeedTransactionId, string matchItemsJson, int matchedBy);

        void UnMatchTx(long bankFeedTransactionId);
    }
}
