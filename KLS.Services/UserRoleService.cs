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
    public class UserRoleService : BaseService, IUserRoleService
    {
        public UserRoleService(IUnitOfWork uow) : base(uow)
        {

        }

        public UserRole GetById(int roleId)
        {
            return Uow.UserRoles.GetById(roleId);
        }

    }
}
