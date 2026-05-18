using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IBankFeedAccountService
    {
        ICollection<BankFeedAccountLookup> GetSelectable();

        BankFeedAccount Save(BankFeedAccount account);
    }
}
