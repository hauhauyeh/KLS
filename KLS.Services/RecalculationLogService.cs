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
    public class RecalculationLogService : BaseService, IRecalculationLogService
    {
        public RecalculationLogService(IUnitOfWork uow) : base(uow)
        {

        }

        public IQueryable<RecalculationLog> GetAllLogs()
        {
            return Uow.RecalculationLogs.GetAll().Take(200);
        }
    }
}
