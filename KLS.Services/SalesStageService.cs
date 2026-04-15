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

        public SalesStage MarkInvoicePrinted(int salesId)
        {
            return Uow.Sales.UpdateStage(salesId, 3);
        }

        public SalesStage MarkPickTicketPrinted(int salesId)
        {
            return Uow.Sales.UpdateStage(salesId, 2);
        }
    }
}
