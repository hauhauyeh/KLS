using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IAccountCategoryService
    {
        IEnumerable<AccountFlatTree> GetFlatTree();

        IEnumerable<AccountFlatTree> GetRecursiveTree();

        AccountCategory GetById(int categoryId);

        AccountCategory Create(AccountCategory category);

        AccountCategory Update(AccountCategory category);

        void Delete(int categoryId);

        void ReorderNode(AccountNodeReorderReq dto);

        void MoveAccount(AccountMoveReq dto);
    }
}
