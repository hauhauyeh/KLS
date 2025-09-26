using KLS.Contract.Interfaces;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PayrollServiceTypeService : BaseService, IPayrollServiceTypeService
    {
        public PayrollServiceTypeService(IUnitOfWork uow) : base(uow)
        {

        }
    }
}
