using KLS.Contract.Interfaces;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class SalesService : BaseService, ISalesService
    {
        public SalesService(IUnitOfWork uow) : base(uow)
        {

        }
    }
}
