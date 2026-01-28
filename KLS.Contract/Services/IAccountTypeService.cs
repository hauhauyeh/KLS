using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IAccountTypeService
    {
        IEnumerable<AccountTypeGroup>? GetList();

        AccountType GetById(int typeId);
    }
}
