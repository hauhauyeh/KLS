using KLS.Contract.Interfaces;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TempTransferFundService : BaseService, ITempTransferFundService
    {
        public TempTransferFundService(IUnitOfWork uow) : base(uow)
        {

        }
    }
}
