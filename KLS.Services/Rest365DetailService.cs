using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class Rest365DetailService : BaseService, IRest365DetailService
    {
        public Rest365DetailService(IUnitOfWork uow) : base(uow)
        {

        }
    }
}
