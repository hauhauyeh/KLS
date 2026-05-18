using KLS.Models;

namespace KLS.Contract.Interfaces
{
    public interface IBankFeedAccountRepository : IRepository<BankFeedAccount>
    {
        BankFeedAccount? GetByAccountId(int accountId);

        BankFeedAccount? GetByLongId(long bankFeedAccountId);
    }
}
