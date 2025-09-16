using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Data.Repositories;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class AccountTypeRepository : KLSRepository<AccountType>, IAccountTypeRepository
    {
        public AccountTypeRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }
    }
}