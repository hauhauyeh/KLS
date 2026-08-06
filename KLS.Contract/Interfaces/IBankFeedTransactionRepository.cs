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

        IQueryable<BankFeedUndepositedPayment> GetUndepositedPayments(BankFeedUndepositedPaymentsReq req);

        int CountUndepositedPayments(BankFeedUndepositedPaymentsReq req);

        IQueryable<BankFeedOpenInvoice> GetOpenInvoices(BankFeedOpenInvoicesReq req);

        int CountOpenInvoices(BankFeedOpenInvoicesReq req);

        int CreateVendorPayment(BankFeedCreateVendorPaymentReq req, string linesJson,
                                string? resolvingLinesJson, int empId);

        int CreateDeposit(BankFeedCreateDepositReq req, string paymentIdsJson, int empId);

        int CreateInvoiceDeposit(BankFeedCreateInvoiceDepositReq req, string linesJson, int empId);

        void MatchTx(long bankFeedTransactionId, string matchItemsJson, int matchedBy);

        void UnMatchTx(long bankFeedTransactionId);
    }
}
