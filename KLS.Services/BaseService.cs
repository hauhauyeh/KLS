using KLS.Contract.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class BaseService
    {
        protected IUnitOfWork Uow { get; }

        public BaseService(IUnitOfWork uow)
        {
            Uow = uow;
        }
    }
}
