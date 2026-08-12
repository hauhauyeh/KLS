using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace KLS.Data.Repositories
{
    public class BankFeedSourceRepository : KLSRepository<BankFeedSource>, IBankFeedSourceRepository
    {
        public BankFeedSourceRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public bool HasActiveSource(long bankFeedTransactionId)
        {
            return DbContext.BankFeedSources
                .Any(c => c.BankFeedTransactionId == bankFeedTransactionId && c.Status == "Active");
        }

        public bool IsGeneratedVendorPayment(int vendorPaymentId)
        {
            return DbContext.BankFeedSources
                .Any(c => c.SourceDocType == "VendorPayment"
                          && c.SourceDocId == vendorPaymentId
                          && c.Status == "Active");
        }

        /// <summary>
        /// The payee used on the most recent Bank Feed charge, so the picker can open
        /// pre-filled. Null before the first charge is ever created.
        /// </summary>
        /// <remarks>
        /// History rather than configuration: it tracks what the business actually does instead
        /// of what someone typed once at deploy time, and it needs no setting, no seed file and
        /// no DBA task to change. Reversed rows count - a reversed charge still tells you which
        /// payee the business uses.
        /// Global rather than per user: a reasonable AP team is one or two people, and scoping
        /// it per user would make the picker open empty once for each of them instead of once
        /// overall.
        /// </remarks>
        public BankFeedChargePayee? GetLastChargePayee()
        {
            // SourceDocId is long (it is polymorphic) while VendorPaymentId is int, so the join
            // needs an explicit widening - C# will not infer it inside an equals clause.
            // 2026-08-12 per-line vendor: projected to the lookup DTO and joined to Vendor for
            // AccountId1, which pre-fills the seeded resolving line's account.
            return (from bfs in DbContext.BankFeedSources
                    join vp in DbContext.VendorPayments on bfs.SourceDocId equals (long)vp.VendorPaymentId
                    join p in DbContext.Payees on vp.PayeeId equals p.PayeeId
                    join v in DbContext.Vendors on p.PayeeId equals v.PayeeId
                    where bfs.Mode == "ResolveDifference"
                    orderby bfs.BankFeedSourceId descending
                    select new BankFeedChargePayee
                    {
                        PayeeId = p.PayeeId,
                        PayeeName = p.PayeeName,
                        AccountId1 = v.AccountId1
                    }).FirstOrDefault();
        }

        public void ReverseGenerated(long bankFeedTransactionId, string? reverseReason, int empId)
        {
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[BankFeed_ReverseGenerated] @BankFeedTransactionId,@ReverseReason,@EmpId",
                new SqlParameter("@BankFeedTransactionId", bankFeedTransactionId),
                new SqlParameter("@ReverseReason", (object?)reverseReason ?? DBNull.Value),
                new SqlParameter("@EmpId", empId));
        }
    }
}
