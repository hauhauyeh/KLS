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
    public class SalesStageService : BaseService, ISalesStageService
    {
        public SalesStageService(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<SalesStage> GetAllSalesStages()
        {
            return Uow.SalesStages.GetAll();
        }
    }
}
