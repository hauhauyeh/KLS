using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
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

        public IEnumerable<SalesStage> GetList()
        {
            return Uow.SalesStages.GetAll();
        }
    }
}
