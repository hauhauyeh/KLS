using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;

namespace KLS.Services
{
    public class BankFeedAccountService : BaseService, IBankFeedAccountService
    {
        public BankFeedAccountService(IUnitOfWork uow) : base(uow)
        {
        }

        public ICollection<BankFeedAccountLookup> GetSelectable()
        {
            var configured = Uow.BankFeedAccounts.GetAll();
            var accounts = Uow.Accounts.GetAll()
                .Where(c => (c.TypeName == "Bank" || c.TypeName == "Cash") && !c.Inactive);

            var qry =
                from acct in accounts
                join feed in configured on acct.AccountId equals feed.AccountId into feedJoin
                from feed in feedJoin.DefaultIfEmpty()
                select new BankFeedAccountLookup
                {
                    BankFeedAccountId = feed != null ? feed.BankFeedAccountId : null,
                    AccountId = acct.AccountId,
                    AccountCode = acct.AccountCode,
                    AccountName = acct.AccountName,
                    TypeName = acct.TypeName,
                    AccountNickname = feed != null ? feed.AccountNickname : null,
                    ImportFormat = feed != null ? feed.ImportFormat : "CSV",
                    IsActive = feed == null || feed.IsActive
                };

            return qry.OrderBy(c => c.TypeName).ThenBy(c => c.AccountName).ToList();
        }

        public BankFeedAccount Save(BankFeedAccount account)
        {
            var existing = account.BankFeedAccountId > 0
                ? Uow.BankFeedAccounts.GetByLongId(account.BankFeedAccountId)
                : Uow.BankFeedAccounts.GetByAccountId(account.AccountId);

            if (existing == null)
            {
                Uow.BankFeedAccounts.Add(account);
                Uow.Commit();
                return account;
            }

            existing.AccountNickname = account.AccountNickname;
            existing.ImportFormat = string.IsNullOrWhiteSpace(account.ImportFormat) ? "CSV" : account.ImportFormat;
            existing.IsActive = account.IsActive;
            existing.UpdatedAt = DateTime.UtcNow;
            Uow.BankFeedAccounts.Update(existing);
            Uow.Commit();
            return existing;
        }
    }
}
