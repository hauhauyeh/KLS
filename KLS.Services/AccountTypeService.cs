using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class AccountTypeService : BaseService, IAccountTypeService
    {
        public AccountTypeService(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<AccountTypeGroup>? GetAllAccountTypes()
        {
            return Uow.AccountTypes.GetAll().GroupBy(c => c.TypeName).Select(c => new AccountTypeGroup
            {
                TypeName = c.Key,
                DetailTypes = c.OrderBy(c => c.DetailType).ToList()
            }).OrderBy(c => c.TypeName);
        }

        public AccountType GetById(int typeId)
        {
            return Uow.AccountTypes.GetById(typeId);
        }
    }
}
