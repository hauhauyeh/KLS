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
    public class PurchaseStageService : BaseService, IPurchaseStageService
    {
        public PurchaseStageService(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<PurchaseStage> GetAllPurchaseStages()
        {
            return Uow.PurchaseStages.GetAll();
        }
    }
}
