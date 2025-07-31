using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ChartOfAccountTypeService : BaseService, IChartOfAccountTypeService
    {
        public ChartOfAccountTypeService(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<AccountTypeGroup>? GetAllAccountTypes()
        {
            return Uow.ChartOfAccountTypes.GetAll().GroupBy(c => c.AccountType).Select(c => new AccountTypeGroup
            {
                AccountType = c.Key,
                DetailTypes = c.OrderBy(c => c.DetailType).ToList()
            }).OrderBy(c => c.AccountType);
        }

        public ChartOfAccountType GetById(int typeId)
        {
            return Uow.ChartOfAccountTypes.GetById(typeId);
        }
    }
}
