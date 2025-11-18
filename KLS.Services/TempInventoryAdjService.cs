using KLS.Contract.Interfaces;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TempInventoryAdjService : BaseService, ITempInventoryAdjService
    {
        public TempInventoryAdjService(IUnitOfWork uow) : base(uow)
        {

        }
    }
}
