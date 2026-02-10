using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class AccountCategoryRepository : KLSRepository<AccountCategory>, IAccountCategoryRepository
    {
        public AccountCategoryRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }
    }
}
