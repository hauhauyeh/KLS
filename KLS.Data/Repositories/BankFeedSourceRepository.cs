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

        public void ReverseVendorPayment(long bankFeedTransactionId, string? reverseReason, int empId)
        {
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[BankFeed_ReverseVendorPayment] @BankFeedTransactionId,@ReverseReason,@EmpId",
                new SqlParameter("@BankFeedTransactionId", bankFeedTransactionId),
                new SqlParameter("@ReverseReason", (object?)reverseReason ?? DBNull.Value),
                new SqlParameter("@EmpId", empId));
        }
    }
}
