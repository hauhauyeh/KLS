using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class BankFeedAccountRepository : KLSRepository<BankFeedAccount>, IBankFeedAccountRepository
    {
        public BankFeedAccountRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public BankFeedAccount? GetByAccountId(int accountId)
        {
            return DbContext.BankFeedAccounts.FirstOrDefault(c => c.AccountId == accountId);
        }

        public BankFeedAccount? GetByLongId(long bankFeedAccountId)
        {
            return DbContext.BankFeedAccounts.FirstOrDefault(c => c.BankFeedAccountId == bankFeedAccountId);
        }
    }
}
