using KLS.Contract.Interfaces;
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
    }
}
